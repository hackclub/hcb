# frozen_string_literal: true

# == Schema Information
#
# Table name: ledger_items
#
#  id                           :bigint           not null, primary key
#  amount_cents                 :integer          not null
#  date                         :datetime         not null
#  marked_no_or_lost_receipt_at :datetime
#  memo                         :text             not null
#  short_code                   :text
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#
class Ledger
  class Item < ApplicationRecord
    self.table_name = "ledger_items"

    include Hashid::Rails
    hashid_config salt: Credentials.fetch(:HASHID_SALT)
    has_paper_trail

    include Commentable
    include Receiptable

    has_many :ledger_mappings, class_name: "Ledger::Mapping", foreign_key: :ledger_item_id
    has_one :primary_mapping, -> { where(on_primary_ledger: true) }, class_name: "Ledger::Mapping", foreign_key: :ledger_item_id
    has_one :primary_ledger, through: :primary_mapping, source: :ledger, class_name: "::Ledger"

    has_many :canonical_transactions, foreign_key: "ledger_item_id"
    has_many :canonical_pending_transactions, foreign_key: "ledger_item_id"
    has_many :all_ledgers, through: :ledger_mappings, source: :ledger, class_name: "::Ledger"

    validates_presence_of :amount_cents, :memo, :date

    before_create :map_to_ledger
    before_create :write_amount_cents

    monetize :amount_cents

    def receipt_required?
      false
    end

    def calculate_amount_cents
      amount_cents = canonical_transactions.sum(:amount_cents)
      amount_cents += canonical_pending_transactions.outgoing.unsettled.sum(:amount_cents)
      if primary_ledger&.event&.can_front_balance?
        fronted_pt_sum = canonical_pending_transactions.incoming.fronted.not_declined.sum(:amount_cents)
        settled_ct_sum = [canonical_transactions.sum(:amount_cents), 0].max
        amount_cents += [fronted_pt_sum - settled_ct_sum, 0].max
      end

      amount_cents
    end

    def calculate_event
      # Transactions sent to an organisation's unique Column account number
      # Also covers ACH transfers, wires, etc. which are sent using this number.
      canonical_transactions.each do |ct|
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

      # Stripe top-ups should always be mapped to NOEVENT
      if canonical_transactions.stripe_top_up.exists?
        return Event.find(EventMappingEngine::EventIds::NOEVENT)
      end

      # Interest payments should always be mapped to HACK_FOUNDATION_INTEREST
      if canonical_transactions.increase_interest.exists? ||
         canonical_transactions.likely_column_interest.exists? ||
         canonical_transactions.svb_sweep_interest.exists?
        return Event.find(EventMappingEngine::EventIds::HACK_FOUNDATION_INTEREST)
      end

      # SVB sweep transactions should always be mapped to SVB_SWEEPS
      if canonical_transactions.to_svb_sweep_account.exists? ||
         canonical_transactions.from_svb_sweep_account.exists? ||
         canonical_transactions.svb_sweep_account.exists?
        return Event.find(EventMappingEngine::EventIds::SVB_SWEEPS)
      end

      # If we're unable to calculate the event from the canonical transactions
      # or there are no canonical transactions, we use CPTs.
      canonical_pending_transactions.each do |cpt|
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
      canonical_transactions.each do |ct|
        if ct.raw_stripe_transaction.present? && (card_grant = ct.raw_stripe_transaction.likely_card_grant)
          return card_grant
        end

        if (card_grant = ct.linked_object.try(:subledger).try(:card_grant))
          return card_grant
        end
      end

      canonical_pending_transactions.each do |cpt|
        if cpt.raw_pending_stripe_transaction.present? && (card_grant = cpt.raw_pending_stripe_transaction.likely_card_grant)
          return card_grant
        end

        if (card_grant = ct.linked_object.try(:subledger).try(:card_grant))
          return card_grant
        end
      end

      nil
    end

    def map_to_ledger
      if card_grant = calculate_card_grant
        ledger = Ledger.find_or_create_by!(primary: true, card_grant:)
      elsif event = calculate_event
        ledger = Ledger.find_or_create_by!(primary: true, event:)
      else
        return nil
      end

      Ledger::Mapping.find_or_create_by!(ledger:, ledger_item: self) do |mapping|
        mapping.on_primary_ledger = true
      end
    end

    def write_amount_cents
      update(amount_cents: calculate_amount_cents)
    end

  end

end
