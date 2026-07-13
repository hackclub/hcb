# frozen_string_literal: true

module CardLocking
  # All card-locking behavior for a charge (HcbCode). Concentrates the coupling
  # to HcbCode in one place so it is easy to tear out when HcbCode is removed.
  # See docs/card-locking/migrating-hcbcode-to-ledger.md.
  module ChargeBehavior
    extend ActiveSupport::Concern

    STRIPE_CARD_JOIN = "INNER JOIN stripe_cards ON raw_stripe_transactions.stripe_transaction->>'card' = stripe_cards.stripe_id"
    STRIPE_CARDHOLDER_JOIN = "INNER JOIN stripe_cardholders ON stripe_cardholders.id = stripe_cards.stripe_cardholder_id"
    EVENT_MAPPING_JOIN = "INNER JOIN canonical_event_mappings ON canonical_event_mappings.canonical_transaction_id = canonical_transactions.id"
    ACTIVE_EVENT_PLAN_JOIN = "INNER JOIN event_plans ON event_plans.event_id = canonical_event_mappings.event_id AND event_plans.aasm_state = 'active'"

    included do
      # Every settled Stripe card charge a cardholder has ever made. Unbounded in
      # time, so callers must supply their own date bound or scan the whole table.
      scope :card_locking_relevant, -> {
        joins(:canonical_transactions)
          .merge(CanonicalTransaction.stripe_transaction)
          .joins(STRIPE_CARD_JOIN)
          .joins(EVENT_MAPPING_JOIN)
          .joins(ACTIVE_EVENT_PLAN_JOIN)
          .where("canonical_transactions.amount_cents < 0")
          .where.not(event_plans: { type: Event::Plan::SalaryAccount.name })
      }
      # card_locking_relevant narrowed to a single cardholder.
      scope :card_locking_relevant_for_cardholder, ->(user_id) {
        card_locking_relevant.joins(STRIPE_CARDHOLDER_JOIN).where(stripe_cardholders: { user_id: })
      }
      # Charges that can count against a cardholder: no receipt, not written off,
      # and settled once enforcement began.
      #
      # This is the live "still missing a receipt" source of truth for candidate
      # discovery and materialization: it reads the actual receipts join and
      # marked_no_or_lost_receipt_at, not the persisted receipt_due_at /
      # receipt_resolved_at fast-path that drives the lock decision. The two are
      # kept deliberately distinct (the persisted columns let the lock query use
      # the partial index and self-heal against this join); a future cleanup must
      # not collapse them.
      scope :card_locking_candidates, -> {
        card_locking_relevant
          .joins(STRIPE_CARDHOLDER_JOIN)
          .left_outer_joins(:receipts)
          .where(receipts: { id: nil })
          .where(marked_no_or_lost_receipt_at: nil)
          .where("canonical_transactions.created_at >= ?", CardLocking::ENFORCEMENT_START_DATE.beginning_of_day)
      }
      # Charges past their deadline and still unresolved. Keys off the persisted
      # columns directly (not the receipts join) so the partial index on
      # receipt_due_at is usable.
      scope :receipt_overdue, ->(now = Time.current) {
        where("hcb_codes.receipt_due_at <= ?", now).where(receipt_resolved_at: nil)
      }
    end

    def card_locking_settled_at
      return unless stripe_card? || stripe_force_capture?
      return @card_locking_settled_at if defined?(@card_locking_settled_at)

      @card_locking_settled_at = if association(:canonical_transactions).loaded?
                                   canonical_transactions.select { |ct| ct.amount_cents.negative? }.min_by(&:created_at)&.created_at
                                 else
                                   canonical_transactions.expense.minimum(:created_at)
                                 end
    end

    def card_locking_chargeable?
      (stripe_card? || stripe_force_capture?) && card_locking_settled_at.present?
    end

    def card_locking_resolved_at
      receipt_at = if association(:receipts).loaded?
                     receipts.map(&:created_at).compact.min
                   else
                     receipts.minimum(:created_at)
                   end
      [receipt_at, marked_no_or_lost_receipt_at].compact.min
    end

    def card_locking_resolved?
      card_locking_resolved_at.present?
    end

    # The single writer of receipt_settled_at / receipt_resolved_at /
    # receipt_due_at. Idempotent. Only populates columns for a receipt-required
    # settled card charge, and clears them if the charge stops being one (e.g. a
    # refund nets it to zero). receipt_resolved_at is frozen once set (never moved
    # here); the destroy callback resets it when a charge becomes unresolved.
    # Callers pass the user's trust state.
    #
    # enforcement_start_date is the cardholder's staged enforcement date (nil if
    # they are not yet enrolled, so no deadline is set and the charge can't lock).
    # Callers iterating a user's charges should resolve it once and pass it;
    # otherwise it is resolved from this charge's own cardholder.
    def materialize_card_locking!(now: Time.current, trusted: false, last_settled_charge_at: nil, enforcement_start_date: :unset)
      unless card_locking_chargeable? && receipt_required?
        clear_card_locking! if receipt_settled_at.present? || receipt_due_at.present? || receipt_resolved_at.present?
        return
      end

      settled_at = receipt_settled_at || card_locking_settled_at
      resolved_at = receipt_resolved_at || card_locking_resolved_at
      if enforcement_start_date == :unset
        enforcement_start_date = CardLocking.enforcement_start_date(stripe_card&.stripe_cardholder&.user)
      end

      due_at =
        if enforcement_start_date && settled_at >= enforcement_start_date.beginning_of_day
          CardLocking::Deadline.new(
            settled_at:, trusted:, last_settled_charge_at:, current_due_at: receipt_due_at, now:
          ).compute
        end

      return if receipt_settled_at == settled_at && receipt_resolved_at == resolved_at && receipt_due_at == due_at

      update_columns(receipt_settled_at: settled_at, receipt_resolved_at: resolved_at, receipt_due_at: due_at)
    end

    def clear_card_locking!
      update_columns(receipt_settled_at: nil, receipt_due_at: nil, receipt_resolved_at: nil)
    end
  end
end
