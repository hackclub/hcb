# frozen_string_literal: true

module CardLocking
  # All card-locking behavior for a charge: a Ledger::Item linked to a
  # CardCharge. The receipt clock runs from the item's settled_at and the
  # persisted deadline (receipt_due_at) lives on the item too. Whether the charge
  # is resolved is never persisted: it is read live from the item's receipts (or
  # its cached receipt_count) and marked_no_or_lost_receipt_at.
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
    # When a charge was resolved: its earliest receipt or its no/lost mark,
    # whichever came first (LEAST skips NULLs), or NULL while it is outstanding.
    # The SQL twin of #card_locking_resolved_at, for plucking it across a pile.
    RESOLVED_AT_SQL = <<~SQL.squish
      LEAST(
        (SELECT MIN(receipts.created_at) FROM receipts
          WHERE receipts.receiptable_type = 'Ledger::Item' AND receipts.receiptable_id = ledger_items.id),
        ledger_items.marked_no_or_lost_receipt_at
      )
    SQL

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
      # discovery and materialization: it reads the actual receipts rows, not the
      # cached receipt_count that receipt_overdue (and its partial index) keys on.
      # The two are kept deliberately distinct (the cached column lets the lock
      # query use the partial index; this check catches a receipt attached by a
      # path that left receipt_count stale); a future cleanup must not collapse
      # them.
      scope :card_locking_candidates, -> {
        card_locking_relevant
          .joins(STRIPE_CARDHOLDER_JOIN)
          .without_receipt
          .where(marked_no_or_lost_receipt_at: nil)
          .where("ledger_items.settled_at >= ?", CardLocking::ENFORCEMENT_START_DATE.beginning_of_day)
      }
      # Charges past their deadline and still unresolved. Keys off the item's own
      # columns (not the receipts check) so the partial index on receipt_due_at
      # (index_ledger_items_on_open_receipt_due_at) is usable.
      scope :receipt_overdue, ->(now = Time.current) {
        where("ledger_items.receipt_due_at <= ?", now).where(receipt_count: 0, marked_no_or_lost_receipt_at: nil)
      }
    end

    def card_locking_chargeable?
      linked_object_type == "CardCharge" && settled_at.present?
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

    # The writer of receipt_due_at (alongside #restart_card_locking_countdown!).
    # Idempotent. Only populates it for a receipt-required settled card charge,
    # and clears it if the charge stops being one (e.g. a refund nets it to zero).
    # Callers pass the user's trust state.
    #
    # enforcement_start_date is the cardholder's staged enforcement date (nil if
    # they are not yet enrolled, so no deadline is set and the charge can't lock).
    # Callers iterating a user's charges should resolve it once and pass it;
    # otherwise it is resolved from this charge's own cardholder.
    def materialize_card_locking!(now: Time.current, trusted: false, last_settled_charge_at: nil, enforcement_start_date: :unset)
      unless card_locking_chargeable? && receipt_required?
        clear_card_locking! if receipt_due_at.present?
        return
      end

      if enforcement_start_date == :unset
        enforcement_start_date = CardLocking.enforcement_start_date(card_locking_cardholder)
      end

      due_at =
        if enforcement_start_date && settled_at >= enforcement_start_date.beginning_of_day
          CardLocking::Deadline.new(
            settled_at:, trusted:, last_settled_charge_at:, current_due_at: receipt_due_at, now:,
            resolved: card_locking_resolved?
          ).compute
        end

      return if receipt_due_at == due_at

      update_columns(receipt_due_at: due_at)
    end

    # The charge's last receipt was just deleted, so it is outstanding again.
    # Restart its countdown: a fresh RECEIPT_DUE_WINDOW from now, so removing the
    # receipt from a months-old charge can't make it overdue (and lock the cards)
    # the moment it's gone. A later deadline the charge already had (a trusted
    # slide, rollout grace) is kept. No-op when the charge gets no deadline at all
    # (not receipt-required, cardholder not enrolled, settled before enforcement).
    # Deadline#compute never moves a future deadline earlier, so the sweep keeps
    # the restarted one.
    def restart_card_locking_countdown!(now: Time.current)
      materialize_card_locking!(now:)
      return if receipt_due_at.nil?

      restarted_due_at = [receipt_due_at, now + CardLocking::RECEIPT_DUE_WINDOW].max
      update_columns(receipt_due_at: restarted_due_at) unless restarted_due_at == receipt_due_at
    end

    def clear_card_locking!
      update_columns(receipt_due_at: nil)
    end
  end
end
