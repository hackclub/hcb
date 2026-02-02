# frozen_string_literal: true

class Ledger
  class Mapper
    def initialize(ledger_item:)
      @ledger_item = ledger_item
    end

    def run
      if card_grant = calculate_card_grant
        ledger = Ledger.find_or_create_by!(primary: true, card_grant:)
      elsif event = calculate_event
        ledger = Ledger.find_or_create_by!(primary: true, event:)
      else
        return nil
      end

      Ledger::Mapping.find_or_create_by!(ledger:, ledger_item: @ledger_item) do |mapping|
        mapping.on_primary_ledger = true
      end
    end

    private

    def calculate_event
      event_from_canonical_transactions ||
        event_from_stripe_top_up ||
        event_from_interest ||
        event_from_svb_sweep ||
        event_from_canonical_pending_transactions
    end

    # Transactions sent to an organisation's unique Column account number.
    # Also covers ACH transfers, wires, etc. which are sent using this number.
    def event_from_canonical_transactions
      @ledger_item.canonical_transactions.each do |ct|
        next unless ct.raw_column_transaction

        column_account_number = Column::AccountNumber.find_by(
          column_id: ct.raw_column_transaction.column_transaction["account_number_id"]
        )
        return column_account_number.event if column_account_number

        # Map transactions on Stripe cards.
        if ct.raw_stripe_transaction.present? && (event = ct.raw_stripe_transaction.likely_event)
          return event
        end

        # Fallback, see if any linked objects have an event.
        if (event = ct.linked_object.try(:event))
          return event
        end
      end

      nil
    end

    # Stripe top-ups should always be mapped to NOEVENT
    def event_from_stripe_top_up
      return unless @ledger_item.canonical_transactions.stripe_top_up.exists?

      Event.find(EventMappingEngine::EventIds::NOEVENT)
    end

    # Interest payments should always be mapped to HACK_FOUNDATION_INTEREST
    def event_from_interest
      return unless @ledger_item.canonical_transactions.increase_interest.exists? ||
                    @ledger_item.canonical_transactions.likely_column_interest.exists? ||
                    @ledger_item.canonical_transactions.svb_sweep_interest.exists?

      Event.find(EventMappingEngine::EventIds::HACK_FOUNDATION_INTEREST)
    end

    # SVB sweep transactions should always be mapped to SVB_SWEEPS
    def event_from_svb_sweep
      return unless @ledger_item.canonical_transactions.to_svb_sweep_account.exists? ||
                    @ledger_item.canonical_transactions.from_svb_sweep_account.exists? ||
                    @ledger_item.canonical_transactions.svb_sweep_account.exists?

      Event.find(EventMappingEngine::EventIds::SVB_SWEEPS)
    end

    # If we're unable to calculate the event from the canonical transactions
    # or there are no canonical transactions, we use CPTs.
    def event_from_canonical_pending_transactions
      @ledger_item.canonical_pending_transactions.each do |cpt|
        # See if linked_object (eg. increase_check, paypal_transfer, wire, etc.) has an event
        if (event = cpt.linked_object.try(:event))
          return event
        end

        # Map transactions on Stripe cards.
        if cpt.raw_pending_stripe_transaction.present? && (event = cpt.raw_pending_stripe_transaction.likely_event)
          return event
        end

        # Use the Column account number on `raw_pending_column_transaction`
        # Currently the only `raw_pending_column_transaction`s are when someone
        # sends an ACH or wire to an organisation's account numbers
        next unless cpt.raw_pending_column_transaction

        column_account_number = Column::AccountNumber.find_by(
          column_id: cpt.raw_pending_column_transaction.column_transaction["account_number_id"]
        )
        return column_account_number.event if column_account_number
      end

      nil
    end

    # CardGrant calculation is significantly simpler.
    # At the moment, only disbursements & Stripe card transactions
    # can exitst on CardGrant's ledger.
    def calculate_card_grant
      @ledger_item.canonical_transactions.each do |ct|
        if ct.raw_stripe_transaction.present? && (card_grant = ct.raw_stripe_transaction.likely_card_grant)
          return card_grant
        end

        if (card_grant = ct.linked_object.try(:subledger).try(:card_grant))
          return card_grant
        end
      end

      @ledger_item.canonical_pending_transactions.each do |cpt|
        if cpt.raw_pending_stripe_transaction.present? && (card_grant = cpt.raw_pending_stripe_transaction.likely_card_grant)
          return card_grant
        end

        if (card_grant = cpt.linked_object.try(:subledger).try(:card_grant))
          return card_grant
        end
      end

      nil
    end

  end
end
