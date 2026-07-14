# frozen_string_literal: true

# == Schema Information
#
# Table name: ledger_items
#
#  id                           :bigint           not null, primary key
#  amount_cents                 :integer          not null
#  comment_count                :integer          default(0), not null
#  custom_memo                  :text
#  datetime                     :datetime         not null
#  linked_object_type           :string
#  marked_no_or_lost_receipt_at :datetime
#  memo                         :text             not null
#  not_admin_only_comment_count :integer          default(0), not null
#  receipt_count                :integer          default(0), not null
#  receipt_required             :boolean
#  short_code                   :text
#  system_memo                  :text
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  author_id                    :bigint
#  linked_object_id             :bigint
#
# Indexes
#
#  index_ledger_items_on_amount_cents     (amount_cents)
#  index_ledger_items_on_author_id        (author_id)
#  index_ledger_items_on_datetime         (datetime)
#  index_ledger_items_on_linked_object    (linked_object_type,linked_object_id)
#  index_ledger_items_on_receipt_missing  (id) WHERE (receipt_required AND (marked_no_or_lost_receipt_at IS NULL) AND (receipt_count = 0))
#  index_ledger_items_on_short_code       (short_code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id)
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
    belongs_to :author, class_name: "User", optional: true

    # TODO: THIS IS SO TEMPORARY REMOVE ASAP
    has_many :comments, -> { order(:created_at) }, as: :commentable, inverse_of: :commentable, through: :hcb_code
    has_many :receipts, as: :receiptable, after_add: :update_task_completion, after_remove: :update_task_completion, through: :hcb_code

    has_many :ledger_mappings, class_name: "Ledger::Mapping", foreign_key: :ledger_item_id, inverse_of: :ledger_item
    has_one :primary_mapping, -> { where(on_primary_ledger: true) }, class_name: "Ledger::Mapping", foreign_key: :ledger_item_id, inverse_of: :ledger_item
    has_one :primary_ledger, through: :primary_mapping, source: :ledger, class_name: "::Ledger"

    has_many :canonical_transactions, foreign_key: "ledger_item_id", inverse_of: :ledger_item
    has_many :canonical_pending_transactions, foreign_key: "ledger_item_id", inverse_of: :ledger_item
    has_many :all_ledgers, through: :ledger_mappings, source: :ledger, class_name: "::Ledger"

    validates_presence_of :amount_cents, :memo, :datetime

    normalizes :memo, with: ->(memo) { memo.strip.presence }
    normalizes :system_memo, with: ->(system_memo) { system_memo.strip.presence }
    normalizes :custom_memo, with: ->(custom_memo) { custom_memo.strip.presence }

    monetize :amount_cents

    after_create_commit :assign_linked_object!

    # map! calls refresh!
    after_create :map!
    after_touch :map!

    scope :missing_receipt, -> { where(receipt_required: true, marked_no_or_lost_receipt_at: nil, receipt_count: 0) }

    # This is defined because the Receiptable concern overrides the receipt_required? method defined by ActiveRecord
    def receipt_required?
      self[:receipt_required]
    end

    def receipt_optional?
      !receipt_required?
    end

    # This is defined to take advantage of this model caching receipt count which the Receiptable concern does not implement
    def missing_receipt?
      receipt_required? && marked_no_or_lost_receipt_at.nil? && receipt_count == 0
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
      amount_cents < 0 && primary_ledger&.receipt_required? && linked_object_type.in?(["Disbursement::Outgoing", "Reimbursement::ExpensePayout"]) && author.present?
    end

    def calculate_system_memo
      case linked_object_type
      when "Invoice"
        "Invoice to #{linked_object.smart_memo}"
      when "Donation"
        "Donation from #{linked_object.smart_memo}"
      when "AchTransfer"
        "ACH to #{linked_object.smart_memo}"
      when "Wire"
        "Wire to #{linked_object.recipient_name}"
      when "PaypalTransfer"
        "PayPal to #{linked_object.recipient_name}"
      when "WiseTransfer"
        "Wise to #{linked_object.recipient_name}"
      when "Check"
        "Check to #{linked_object.smart_memo}"
      when "IncreaseCheck"
        "Check to #{linked_object.recipient_name}"
      when "CheckDeposit"
        "Check deposit"
      when "Disbursement::Outgoing"
        if linked_object.card_grant.present?
          "Grant to #{linked_object.card_grant.user.name}"
        elsif linked_object.destination_subledger.present?
          "Topup of grant to #{linked_object.destination_subledger.card_grant.user.name}"
        elsif linked_object.source_subledger.present? && linked_object.source_subledger.card_grant.active?
          "Withdrawal from grant to #{linked_object.source_subledger.card_grant.user.name}"
        elsif linked_object.source_subledger.present? && !linked_object.source_subledger.card_grant.active?
          "Return of funds from #{linked_object.source_subledger.card_grant.expired? ? "expired" : "canceled"} grant to #{linked_object.source_subledger.card_grant.user.name}"
        else
          "Transfer to #{linked_object.destination_event.name}"
        end
      when "Disbursement::Incoming"
        if linked_object.source_subledger.present? && linked_object.source_subledger.card_grant.active?
          "Withdrawal from grant to #{linked_object.source_subledger.card_grant.user.name}"
        elsif linked_object.source_subledger.present? && !linked_object.source_subledger.card_grant.active?
          "Return of funds from #{linked_object.source_subledger.card_grant.expired? ? "expired" : "canceled"} grant to #{linked_object.source_subledger.card_grant.user.name}"
        elsif linked_object.card_grant.present?
          "Grant to #{linked_object.card_grant.user.name}"
        elsif linked_object.destination_subledger.present?
          "Topup of grant to #{linked_object.destination_subledger.card_grant.user.name}"
        else
          "Transfer from #{linked_object.source_event.name}"
        end
      when "StripeServiceFee"
        linked_object.stripe_description
      when "BankFee"
        if linked_object.amount_cents.negative? && linked_object.fee_revenue.present?
          return "Fiscal sponsorship fee for #{linked_object.fee_revenue.start.strftime("%-m/%-d")} to #{linked_object.fee_revenue.end.strftime("%-m/%-d")}"
        elsif linked_object.amount_cents.negative?
          return "Fiscal sponsorship"
        else
          return "Fiscal sponsorship fee credit"
        end
      when "FeeRevenue"
        "Fee revenue for #{linked_object.start.strftime("%-m/%-d")} to #{linked_object.end.strftime("%-m/%-d")}"
      when "Reimbursement::PayoutHolding"
        "Payout holding for reimbursement report #{linked_object.report.hashid}"
      when "Reimbursement::ExpensePayout"
        linked_object.expense.memo
      when "CardCharge"
        network_id = linked_object.merchant_data&.dig("network_id")
        merchant_name = YellowPages::Merchant.lookup(network_id:).name if network_id.present?
        merchant_name || linked_object.merchant_data&.dig("name") || "Card charge at unknown merchant"
      end
    end

    def calculate_author
      case linked_object_type
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
      when "CardCharge"
        linked_object&.stripe_cardholder&.user
      end
    end

    # refresh! should always be called after any non-caching aspect of a ledger item changes (e.g. remapped or custom memo changes).
    # refresh! will update all cached aspects of a ledger item after this non-caching change occurs.
    # refresh! should not update any non-caching columns
    def refresh!
      # `after_create :refresh!` runs before any ledger mappings exist, which
      # memoizes `primary_ledger` as nil on this instance. Reset the association
      # caches so refresh! always recomputes from current database state (e.g.
      # after a mapping is created).
      association(:primary_mapping).reset
      association(:primary_ledger).reset

      self.amount_cents = calculate_amount_cents
      self.author = calculate_author
      self.comment_count = comments.count
      self.not_admin_only_comment_count = comments.not_admin_only.count
      self.receipt_count = receipts.count
      self.receipt_required = calculate_receipt_required
      # TODO: only update this when the transaction gets its first CPT and then first CT assigned. currently it updates on every refresh
      self.system_memo = calculate_system_memo
      self.memo = self.custom_memo || self.system_memo || self.canonical_transactions.first&.memo || self.canonical_pending_transactions.first&.memo || "Transaction"

      save!
    end

    def update_custom_memo!(memo)
      # TODO: remove CT and CPT updates because they are HCB code specific
      ActiveRecord::Base.transaction do
        if hcb_code.present?
          hcb_code.canonical_transactions.each { |ct| ct.update!(custom_memo: memo) }
          hcb_code.canonical_pending_transactions.each { |cpt| cpt.update!(custom_memo: memo) }
        end
        update!(custom_memo: memo)
      end

      refresh!
    end

    def map!
      Ledger::Mapper.new(ledger_item: self).run
      refresh!
    end

    def humanized_type
      type_metadata.first
    end

    # TODO: add support for card charge icons
    def icon
      type_metadata.last
    end

    def sign
      return :positive if amount_cents.positive?
      return :negative if amount_cents.negative?

      :zero
    end

    private

    def assign_linked_object!
      # Once a linked object is assigned, it should never be changed.
      # In the event of a merger of ledger items (e.g. mapping a CT to an LI with an existing CPT),
      # the ledger item with the CPT will persist, and the ledger item with the CT will be destroyed.
      # No linked objects will be changed.
      return if linked_object.present?

      linked_object = (canonical_pending_transactions.order(date: :asc).map(&:linked_object) + canonical_transactions.order(date: :asc).map(&:linked_object_v2)).compact.first

      update!(linked_object:) if linked_object.present?
    end

    def type_metadata
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
        "CardCharge": ["Card charge", "card"]
      }[linked_object_type&.to_sym] || ["Bank account transaction", "cash"]
    end

  end

end
