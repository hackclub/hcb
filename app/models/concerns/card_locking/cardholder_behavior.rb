# frozen_string_literal: true

module CardLocking
  # All card-locking behavior for a cardholder (User): the lock decision, trust
  # assessment, and the outstanding/overdue queries.
  #
  # All of these intentionally consider every cardholder the user owns
  # (stripe_cardholders has no DB uniqueness on user_id), so the lock decision can
  # never diverge from the notification/candidate set.
  module CardholderBehavior
    extend ActiveSupport::Concern

    class_methods do
      def card_locking_candidates
        candidate_user_ids = Ledger::Item.card_locking_candidates.select("DISTINCT stripe_cardholders.user_id")

        where(cards_locked: true).or(where(id: candidate_user_ids)).distinct
      end
    end

    def cards_should_lock?(now: Time.current)
      return false if card_locking_suppressed?(now:)

      card_locking_has_overdue_charge?(now:)
    end

    def last_settled_charge_at
      return nil unless stripe_cardholder

      Ledger::Item.card_locking_relevant_for_cardholder(id).maximum(:settled_at)
    end

    # Trusted iff on-time rate >= 80% over the last 6 months AND the most recent
    # determined charge was on time. Determined = resolved, or overdue-and-unresolved.
    # Not-yet-due unresolved charges are excluded. Resolution is read live
    # (RESOLVED_AT_SQL), so a charge whose receipts were all deleted is unresolved
    # again and is judged against its restarted deadline. Constant query count
    # regardless of history size (one pluck of scalars).
    def receipt_trusted?(now: Time.current)
      return false unless stripe_cardholder

      rows = Ledger::Item.card_locking_relevant_for_cardholder(id)
                         .where("ledger_items.settled_at >= ?", CardLocking::TRUST_LOOKBACK.ago)
                         .distinct
                         .pluck(:id, :settled_at, :receipt_due_at, Arel.sql(CardLocking::ChargeBehavior::RESOLVED_AT_SQL))

      considered = rows.filter_map do |id, settled, due, resolved|
        next if settled.nil?

        if resolved
          # Resolved pre-enforcement charges never got a real receipt_due_at, so
          # synthesize a 7-day due date from settled_at. This lets a pre-enforcement
          # receipt upload still count as on time and earn trust.
          [id, settled, resolved <= (due || settled + CardLocking::RECEIPT_DUE_WINDOW)]
        elsif due && due <= now
          [id, settled, false] # overdue, unresolved
        end
        # not-yet-due unresolved -> filtered out (block returns nil)
      end
      return false if considered.empty?

      on_time_count = considered.count { |_id, _settled, on_time| on_time }
      # Deterministic recency: break settled_at ties by id.
      most_recent = considered.max_by { |id, settled, _on_time| [settled, id] }

      CardLocking::TrustAssessment.new(
        on_time_count:, considered_count: considered.size, most_recent_on_time: most_recent[2]
      ).trusted?
    end

    def card_locking_has_overdue_charge?(now: Time.current)
      card_locking_overdue_charges(now:).exists?
    end

    # Any outstanding charge within WARNING_LEAD_TIME of its deadline (or already
    # past it). Gates the pre-lock warning so fresh charges don't trigger it.
    def card_locking_has_approaching_charge?(now: Time.current)
      card_locking_overdue_charges(now: now + CardLocking::WARNING_LEAD_TIME).exists?
    end

    def card_locking_suppressed?(now: Time.current)
      card_locking_suppressed_until.present? && card_locking_suppressed_until > now
    end

    # Overdue charges: past deadline and still missing a receipt, by the item's
    # own columns (receipt_due_at, receipt_required, receipt_count and
    # marked_no_or_lost_receipt_at), which the partial index on receipt_due_at
    # covers.
    def card_locking_overdue_charges(now: Time.current)
      return Ledger::Item.none unless stripe_cardholder

      Ledger::Item.card_locking_candidates
                  .where(stripe_cardholders: { user_id: id })
                  .receipt_overdue(now)
                  .distinct
    end

    # All outstanding charges for this cardholder: the Receipt Bin's pile
    # (User#card_charges_missing_receipt) narrowed to settled, enforcement-era
    # charges, the ones that carry a deadline.
    def card_locking_outstanding_charges
      return Ledger::Item.none unless stripe_cardholder

      Ledger::Item.card_locking_candidates
                  .where(stripe_cardholders: { user_id: id })
                  .distinct
    end

    def card_locking_outstanding_count
      card_locking_outstanding_charges.count
    end

    # The soonest deadline in the outstanding pile, or nil when nothing is
    # outstanding (or this cardholder isn't enrolled, so their charges carry no
    # receipt_due_at and MIN ignores the NULLs). This is what every "your next
    # receipt is due in X" countdown counts down to.
    def card_locking_next_due_at
      card_locking_outstanding_charges.minimum(:receipt_due_at)
    end
  end
end
