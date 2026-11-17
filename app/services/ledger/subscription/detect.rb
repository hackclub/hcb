# frozen_string_literal: true

class Ledger
  class Subscription
    # Given a settled card charge, links it to the subscription it pays for, or
    # creates a subscription when this charge and the earlier unlinked ones from
    # the same merchant form a cadence. See Subscription for what is covered.
    #
    # Idempotent: a charge that is already linked is left alone.
    class Detect
      MIN_CHARGES = 3
      MIN_YEARLY_CHARGES = 2
      # A gap may span this many cycles (two skipped months, say).
      MAX_CYCLES = 3
      # How far a charge may be from a whole cycle to start a flat subscription,
      # as a fraction. Tighter than Subscription::TIMING_TOLERANCE, which is for
      # charges joining one and for usage billing: at 20%, real data had chains
      # forming among frequent purchases of one price. Only known cadences are
      # tried for the same reason: free-form ones (every 43 days) were almost all
      # coincidences. Subscription#record_charge uses it too, to tell whether a
      # late charge comes a whole number of cycles after the last one.
      CHAIN_TOLERANCE = 0.1
      # The card is a signal, not a requirement. Charges on several cardholders'
      # cards can still start a subscription, but need stronger evidence: this
      # many charges, the exact amount, and no skipped cycles.
      MIN_OTHER_CARD_CHARGES = 4
      # A usage bill rarely repeats an amount, so when one amount is more than
      # this share of the charges, they're a flat price mixed with something
      # else: a one-off, or a second subscription.
      MAX_REPEATED_AMOUNT_SHARE = Rational(1, 3)
      # Long enough to hold two yearly charges.
      LOOKBACK = 15.months

      # Another process is detecting, recomputing or rebuilding subscriptions
      # for this ledger and merchant. The jobs try again later.
      class Busy < StandardError; end

      # Detection, recomputes and rebuilds for one ledger and merchant take an
      # advisory lock on the pair, so they never run alongside each other. The
      # two-integer form keeps these keys apart from single-key advisory locks
      # elsewhere in the app; both are hashes, since ledger ids can outgrow the
      # 32-bit integers it takes. A collision only makes a job wait its turn.
      def self.advisory_lock_sql(function, ledger, merchant_key)
        Subscription.sanitize_sql_array(["SELECT #{function}(hashtext('ledger_subscriptions'), hashtext(?))", "#{ledger.id}:#{merchant_key}"])
      end

      # Takes the lock until the current transaction ends, or raises Busy.
      def self.lock!(ledger, merchant_key)
        raise Busy unless Subscription.connection.select_value(advisory_lock_sql("pg_try_advisory_xact_lock", ledger, merchant_key))
      end

      # The ledger's online card charges at a merchant that aren't linked yet.
      # Charges without a card can't be told apart by cardholder, so they're left
      # out.
      def self.unlinked_charges(ledger:, merchant_key:)
        charges = CardCharge.where(merchant_network_id: merchant_key).where.not(stripe_card_id: nil).card_not_present

        Ledger::Item.subscription_eligible.where(subscription_id: nil).with_primary_ledger(ledger.id).where(linked_object_id: charges.select(:id))
      end

      # Forgets the ledger's subscriptions at a merchant and detects them again
      # from its charges, so the result doesn't depend on the order the charges
      # settled or were backfilled in.
      #
      # Holds the lock for the whole replay on a session, not in a transaction,
      # so the charges it links aren't held locked until it finishes. Each run
      # takes the lock again, which the same session can. Inside a transaction
      # that failed, it couldn't release the lock, so it refuses to start there.
      def self.rebuild(ledger:, merchant_key:)
        connection = Subscription.connection
        raise ArgumentError, "can't rebuild subscriptions inside a transaction" if connection.current_transaction.joinable?

        connection.execute(advisory_lock_sql("pg_advisory_lock", ledger, merchant_key))
        begin
          ledger.subscriptions.where(merchant_key:).destroy_all
          # Oldest first, so not find_each, which goes by id. Each run only links
          # charges up to its own, so the later ones loaded here aren't stale.
          unlinked_charges(ledger:, merchant_key:).order(:datetime, :id).each { |ledger_item| new(ledger_item).run }
        ensure
          connection.execute(advisory_lock_sql("pg_advisory_unlock", ledger, merchant_key))
        end
      end

      def initialize(ledger_item)
        @item = ledger_item
      end

      def run
        return unless @item.subscription_candidate?

        @charge = @item.linked_object
        @ledger = @item.primary_ledger
        @rail = @charge&.stripe_card
        # shortcut: merchants without a Stripe network ID are skipped, key them by name if that turns out to be common
        @merchant_key = @charge&.merchant_network_id
        return if @ledger.nil? || @rail.nil? || @merchant_key.blank? || @charge.card_present?

        Subscription.transaction do
          self.class.lock!(@ledger, @merchant_key)
          link_to_existing || create_from_history
        end
      end

      private

      def link_to_existing
        amount_cents = @item.amount_cents.abs
        subscription = @ledger.subscriptions.where(merchant_key: @merchant_key).includes(:payment_rail)
                              .select { |s| same_cardholder?(s.payment_rail) ? s.due?(@item.datetime) && s.amount_fits?(amount_cents) : takes_over?(s, amount_cents) }
                              .min_by { |s| [same_cardholder?(s.payment_rail) ? 0 : 1, s.payment_rail == @rail ? 0 : 1, (s.amount_cents - amount_cents).abs, (s.next_expected_at - @item.datetime).abs] }
        return unless subscription

        subscription.link!(@item, payment_rail: @rail)
        subscription
      end

      # A replaced card belongs to the same cardholder, so it counts as the same
      # card. On a ledger where many people hold cards, someone else's charge at
      # the same merchant is usually their own subscription.
      def same_cardholder?(card)
        card == @rail || card.stripe_cardholder_id == @rail.stripe_cardholder_id
      end

      # Someone else's charge joins at the exact amount once the cardholder has
      # missed a whole cycle, around when the next charge would be due and before
      # the subscription lapses: it has likely moved to their card. Earlier, the
      # cardholder may still pay late, and it's more likely the other person's own
      # subscription at the same price.
      def takes_over?(subscription, amount_cents)
        overdue_days = (@item.datetime - subscription.next_expected_at) / 1.day
        cadence_days = subscription.cadence_days

        !subscription.variable_amount? && subscription.amount_cents == amount_cents &&
          overdue_days > (1 - Subscription::TIMING_TOLERANCE) * cadence_days && overdue_days <= cadence_days
      end

      # Tries, in order: this cardholder's charges of this exact amount (a flat
      # price), all of this cardholder's charges (usage billing), then charges of
      # this exact amount on any card.
      def create_from_history
        mine = history.select { |item| same_cardholder?(item.linked_object.stripe_card) }

        flat(same_amount(mine), max_cycles: MAX_CYCLES, min_charges: MIN_CHARGES) ||
          variable(mine) ||
          flat(same_amount(history), max_cycles: 1, min_charges: MIN_OTHER_CARD_CHARGES)
      end

      def same_amount(items)
        items.select { |item| item.amount_cents == @item.amount_cents }
      end

      # This merchant's unlinked online charges on the ledger, up to this one.
      def history
        @history ||= self.class.unlinked_charges(ledger: @ledger, merchant_key: @merchant_key)
                         .where(datetime: (@item.datetime - LOOKBACK)..@item.datetime)
                         .includes(linked_object: [:stripe_card, :raw_stripe_transactions])
                         .order(:datetime, :id)
                         .to_a
      end

      # A flat price: the longest chain of same-amount charges ending at this one,
      # among the cadences whose chain is long enough. A chain that skips a cycle
      # at most steps is really a longer cadence, and between equally long chains
      # the one that skips fewest wins, so a monthly charge isn't read as biweekly
      # with gaps.
      def flat(items, max_cycles:, min_charges:)
        cadence_days, chain = Subscription::CADENCES.keys.filter_map do |days|
          charges, skips = walk_chain(items, days, max_cycles)
          # Three yearly charges would need over two years of history.
          needed = days == 365 && max_cycles > 1 ? MIN_YEARLY_CHARGES : min_charges
          [days, charges, skips] if charges.size >= needed && skips * 2 <= charges.size - 1
        end.max_by { |_days, charges, skips| [charges.size, -skips] }

        create(chain, variable_amount: false, cadence_days:) if chain
      end

      # Walks back from this charge one cycle at a time, taking the charge closest
      # to each step and skipping up to max_cycles - 1 cycles. Walking a chain,
      # rather than requiring every charge to fit, finds a subscription among
      # one-off purchases, retries, and a second subscription at the same price.
      def walk_chain(items, cadence_days, max_cycles)
        chain = [@item]
        skips = 0

        loop do
          earlier = items.select { |item| item.datetime < chain.first.datetime }
          step, previous = (1..max_cycles).filter_map do |k|
            closest = earlier.min_by { |item| off_by(item, chain.first, k * cadence_days) }
            [k, closest] if closest && off_by(closest, chain.first, k * cadence_days) <= CHAIN_TOLERANCE * cadence_days
          end.first
          return [chain, skips] if previous.nil?

          skips += 1 if step > 1
          chain.unshift(previous)
        end
      end

      def off_by(earlier, later, days)
        (days_between(earlier, later) - days).abs
      end

      # Usage billing: every charge from the merchant, each gap exactly one cycle
      # of the same known cadence, and amounts that vary.
      def variable(items)
        return if items.size < MIN_CHARGES
        return if items.map(&:amount_cents).tally.values.max > items.size * MAX_REPEATED_AMOUNT_SHARE

        gaps = items.each_cons(2).map { |a, b| days_between(a, b) }
        cadence_days = Subscription::CADENCES.keys.find do |days|
          gaps.all? { |gap| (gap - days).abs <= Subscription::TIMING_TOLERANCE * days }
        end

        create(items, variable_amount: true, cadence_days:) if cadence_days
      end

      def days_between(a, b)
        (b.datetime - a.datetime) / 1.day
      end

      def create(items, variable_amount:, cadence_days:)
        subscription = Subscription.new(
          ledger: @ledger,
          merchant_key: @merchant_key,
          name: YellowPages::Merchant.lookup(network_id: @merchant_key).name || @charge.merchant_data&.dig("name") || @merchant_key,
          variable_amount:,
          cadence_days:
        )
        subscription.replay(items)

        # A savepoint, so the rollback below still undoes this when a caller has
        # a transaction open.
        Subscription.transaction(requires_new: true) do
          subscription.save!
          # Another job got to some of these charges first, or one changed or
          # moved to another ledger: leave them be.
          linked = Subscription.linkable_items.where(id: items.map(&:id)).with_primary_ledger(@ledger.id).update_all(subscription_id: subscription.id)
          raise ActiveRecord::Rollback if linked != items.size
        end

        subscription.tap(&:score!) if subscription.persisted?
      end

    end

  end

end
