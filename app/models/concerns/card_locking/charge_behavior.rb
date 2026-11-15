# frozen_string_literal: true

module CardLocking
  # All card-locking behavior for a charge: a Ledger::Item linked to a
  # CardCharge. The persisted timing (card_charge_settled_at, receipt_due_at,
  # receipt_resolved_at) lives on the item.
  module ChargeBehavior
    extend ActiveSupport::Concern

    CARD_CHARGE_JOIN = "INNER JOIN card_charges ON ledger_items.linked_object_type = 'CardCharge' AND card_charges.id = ledger_items.linked_object_id"
    STRIPE_CARD_JOIN = "INNER JOIN stripe_cards ON stripe_cards.id = card_charges.stripe_card_id"
    STRIPE_CARDHOLDER_JOIN = "INNER JOIN stripe_cardholders ON stripe_cardholders.id = stripe_cards.stripe_cardholder_id"
    # The item's primary ledger is owned by an event or by a card grant, whose
    # charges count against the grant's event.
    PRIMARY_LEDGER_JOIN = <<~SQL.squish
      INNER JOIN ledger_mappings ON ledger_mappings.ledger_item_id = ledger_items.id AND ledger_mappings.on_primary_ledger
      INNER JOIN ledgers ON ledgers.id = ledger_mappings.ledger_id
      LEFT JOIN card_grants ON card_grants.id = ledgers.card_grant_id
    SQL
    ACTIVE_EVENT_PLAN_JOIN = "INNER JOIN event_plans ON event_plans.event_id = COALESCE(ledgers.event_id, card_grants.event_id) AND event_plans.aasm_state = 'active'"

    included do
      # Every settled Stripe card charge a cardholder has ever made. Unbounded in
      # time, so callers must supply their own date bound or scan the whole table.
      scope :card_locking_relevant, -> {
        joins(CARD_CHARGE_JOIN)
          .joins(STRIPE_CARD_JOIN)
          .joins(PRIMARY_LEDGER_JOIN)
          .joins(ACTIVE_EVENT_PLAN_JOIN)
          .where("ledger_items.amount_cents < 0")
          .where.not(settled_at: nil)
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
      # discovery and materialization: it reads the actual receipts and
      # marked_no_or_lost_receipt_at, not the persisted receipt_due_at /
      # receipt_resolved_at fast-path that drives the lock decision. The two are
      # kept deliberately distinct (the persisted columns let the lock query use
      # the partial index and self-heal against this check); a future cleanup must
      # not collapse them.
      scope :card_locking_candidates, -> {
        card_locking_relevant
          .joins(STRIPE_CARDHOLDER_JOIN)
          .without_receipt
          .where(marked_no_or_lost_receipt_at: nil)
          .where("ledger_items.settled_at >= ?", CardLocking::ENFORCEMENT_START_DATE.beginning_of_day)
      }
      # Charges past their deadline and still unresolved. Keys off the persisted
      # columns directly (not the receipts check) so the partial index on
      # receipt_due_at is usable.
      scope :receipt_overdue, ->(now = Time.current) {
        where("ledger_items.receipt_due_at <= ?", now).where(receipt_resolved_at: nil)
      }
    end

    # When the charge settled for the purposes of its receipt clock: the moment
    # HCB imported its first captured transaction.
    def card_locking_settled_at
      return unless linked_object_type == "CardCharge"
      return @card_locking_settled_at if defined?(@card_locking_settled_at)

      @card_locking_settled_at = if association(:canonical_transactions).loaded?
                                   canonical_transactions.select { |ct| ct.amount_cents.negative? }.min_by(&:created_at)&.created_at
                                 else
                                   canonical_transactions.expense.minimum(:created_at)
                                 end
    end

    def card_locking_chargeable?
      linked_object_type == "CardCharge" && card_locking_settled_at.present?
    end

    # The cardholder whose cards this charge can lock: always the person on the
    # charge's Stripe card, never whoever uploaded the receipt (an org teammate
    # may, or an email-link upload has no user at all). Nil for anything that
    # isn't a card charge.
    def card_locking_cardholder
      linked_object&.stripe_cardholder&.user if linked_object_type == "CardCharge"
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

    # The single writer of card_charge_settled_at / receipt_resolved_at /
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
        clear_card_locking! if card_charge_settled_at.present? || receipt_due_at.present? || receipt_resolved_at.present?
        return
      end

      settled_at = card_charge_settled_at || card_locking_settled_at
      resolved_at = receipt_resolved_at || card_locking_resolved_at
      if enforcement_start_date == :unset
        enforcement_start_date = CardLocking.enforcement_start_date(card_locking_cardholder)
      end

      due_at =
        if enforcement_start_date && settled_at >= enforcement_start_date.beginning_of_day
          CardLocking::Deadline.new(
            settled_at:, trusted:, last_settled_charge_at:, current_due_at: receipt_due_at, now:,
            resolved: resolved_at.present?
          ).compute
        end

      return if card_charge_settled_at == settled_at && receipt_resolved_at == resolved_at && receipt_due_at == due_at

      update_columns(card_charge_settled_at: settled_at, receipt_resolved_at: resolved_at, receipt_due_at: due_at)
    end

    def clear_card_locking!
      update_columns(card_charge_settled_at: nil, receipt_due_at: nil, receipt_resolved_at: nil)
    end
  end
end
