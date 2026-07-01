# frozen_string_literal: true

# == Schema Information
#
# Table name: ledger_items
#
#  id                           :bigint           not null, primary key
#  amount_cents                 :integer          not null
#  datetime                     :datetime         not null
#  linked_object_type           :string
#  marked_no_or_lost_receipt_at :datetime
#  memo                         :text             not null
#  short_code                   :text
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  linked_object_id             :bigint
#
# Indexes
#
#  index_ledger_items_on_amount_cents   (amount_cents)
#  index_ledger_items_on_datetime       (datetime)
#  index_ledger_items_on_linked_object  (linked_object_type,linked_object_id)
#  index_ledger_items_on_short_code     (short_code) UNIQUE
#
class Ledger
  class Item < ApplicationRecord
    self.table_name = "ledger_items"

    include Hashid::Rails
    has_paper_trail

    include Commentable
    include Receiptable

    has_one :hcb_code, class_name: "HcbCode", required: false, foreign_key: "ledger_item_id", inverse_of: :ledger_item
    belongs_to :linked_object, polymorphic: true, optional: true

    has_many :ledger_mappings, class_name: "Ledger::Mapping", foreign_key: :ledger_item_id, inverse_of: :ledger_item
    has_one :primary_mapping, -> { where(on_primary_ledger: true) }, class_name: "Ledger::Mapping", foreign_key: :ledger_item_id, inverse_of: :ledger_item
    has_one :primary_ledger, through: :primary_mapping, source: :ledger, class_name: "::Ledger"

    has_many :canonical_transactions, foreign_key: "ledger_item_id", inverse_of: :ledger_item
    has_many :canonical_pending_transactions, foreign_key: "ledger_item_id", inverse_of: :ledger_item
    has_many :all_ledgers, through: :ledger_mappings, source: :ledger, class_name: "::Ledger"

    validates_presence_of :amount_cents, :memo, :datetime

    monetize :amount_cents

    def receipt_required?
      return false if amount_cents >= 0

      if primary_ledger.event.present?
        return false unless primary_ledger.event.plan.receipts_required?
      else
        return false unless primary_ledger.card_grant.event.plan.receipts_required?
      end

      true
    end

    def calculate_amount_cents
      amount_cents = canonical_transactions.sum(:amount_cents)
      amount_cents += canonical_pending_transactions.outgoing.unsettled.sum(:amount_cents)
      if primary_ledger&.can_front_balance?
        fronted_pt_sum = canonical_pending_transactions.incoming.fronted.not_declined.sum(:amount_cents)
        settled_ct_sum = [canonical_transactions.sum(:amount_cents), 0].max
        amount_cents += [fronted_pt_sum - settled_ct_sum, 0].max
      end

      amount_cents
    end

    def write_amount_cents!
      update(amount_cents: calculate_amount_cents)
    end

    def map!
      Ledger::Mapper.new(ledger_item: self).run
      write_amount_cents!
    end

    def humanized_type
      type_metadata.first
    end

    def icon
      type_metadata.last
    end

    def sign
      return :positive if amount_cents.positive?
      return :negative if amount_cents.negative?

      :zero
    end

    private

    def type_metadata
      # TODO: Cache the transaction type for non-linked object ledger items
      {
        "Disbursement::Incoming": ["Incoming transfer", "door-enter"],
        "Disbursement::Outgoing": ["Outgoing transfer", "door-leave"],
        "Reimbursement::ExpensePayout": ["Reimbursement", "reimbursement"],
        "Reimbursement::PayoutHolding": ["Reimbursement payout holding", "reimbursement"],
        "AchTransfer": ["Outgoing ACH", "payment-transfer"],
        "BankFee": ["Fiscal sponsorship fee", "bank-icon"],
        "Check": ["Mailed check", "email"],
        "IncreaseCheck": ["Mailed check", "email"],
        "CheckDeposit": ["Check deposit", "cheque"],
        "Donation": ["Donation", "support"],
        "FeeRevenue": ["Fee revenue", "bank-icon"],
        "Invoice": ["Invoice", "payment-docs"],
        "PaypalTransfer": ["PayPal transfer", "paypal"],
        "Wire": ["Wire", "web"],
        "WiseTransfer": ["Wise transfer", "wise"],
        "RawPendingStripeTransaction": ["Card charge", "card"],
        "RawStripeTransaction": ["Card charge", "card"]
      }[(linked_object_type || raw_pending_transaction_type || raw_transaction_type)&.to_sym] || ["Bank account transaction", "cash"]
    end

    def raw_pending_transaction_type
      canonical_pending_transactions.map(&:transaction_source_type).compact.first
    end

    def raw_transaction_type
      canonical_transactions.map(&:transaction_source_type).compact.first
    end

  end

end
