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
#  receipt_required             :boolean
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

    after_create :refresh!
    after_touch :refresh!

    # This is defined because the Receiptable concern overrides the receipt_required? method defined by ActiveRecord
    def receipt_required?
      self[:receipt_required]
    end

    def receipt_optional?
      !receipt_required?
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

    def calculate_receipt_required
      amount_cents < 0 && primary_ledger&.receipt_required? && transaction_type != "Disbursement::Outgoing"
    end

    def refresh!
      # `after_create :refresh!` runs before any ledger mappings exist, which
      # memoizes `primary_ledger` as nil on this instance. Reset the association
      # caches so refresh! always recomputes from current database state (e.g.
      # after a mapping is created).
      association(:primary_mapping).reset
      association(:primary_ledger).reset

      update(amount_cents: calculate_amount_cents)
      update(receipt_required: calculate_receipt_required)
    end

    def map!
      Ledger::Mapper.new(ledger_item: self).run
      refresh!
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

    def author
      case transaction_type
      when "AchTransfer"
        linked_object&.creator
      when "CheckDeposit"
        linked_object&.created_by
      when "Check"
        linked_object&.creator
      when "IncreaseCheck"
        linked_object&.user
      when "Disbursement::Outgoing"
        linked_object&.requested_by
      when "Disbursement::Incoming"
        linked_object&.requested_by
      when "Reimbursement::ExpensePayout"
        linked_object&.expense&.report&.user
      when "PaypalTransfer"
        linked_object&.user
      when "Donation"
        linked_object&.collected_by if linked_object&.in_person?
      when "Wire"
        linked_object&.user
      when "WiseTransfer"
        linked_object&.user
      when "StripeCardCharge"
        stripe_cardholder&.user
      when "RawPendingStripeTransaction"
        stripe_cardholder&.user
      when "RawStripeTransaction"
        stripe_cardholder&.user
      end
    end

    # TODO: get rid of this method once CardCharge is created as an LO
    def stripe_cardholder
      canonical_pending_transactions.first.try(:stripe_cardholder) || canonical_transactions.first.try(:stripe_cardholder)
    end

    private

    # TODO: replace usages of this with linked_object_type once all LOs are created
    def transaction_type
      linked_object_type || raw_pending_transaction_type || raw_transaction_type
    end

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
        "StripeServiceFee": ["Stripe service fee", "cash"],
        "StripeCardCharge": ["Card charge", "card"],
        "RawPendingStripeTransaction": ["Card charge", "card"],
        "RawStripeTransaction": ["Card charge", "card"]
      }[transaction_type&.to_sym] || ["Bank account transaction", "cash"]
    end

    def raw_pending_transaction_type
      canonical_pending_transactions.map(&:transaction_source_type).compact.first
    end

    def raw_transaction_type
      canonical_transactions.map(&:transaction_source_type).compact.first
    end

  end

end
