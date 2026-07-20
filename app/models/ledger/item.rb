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
#  status                       :string
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
#  index_ledger_items_on_status           (status)
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id)
#
class Ledger
  class Item < ApplicationRecord
    self.table_name = "ledger_items"

    include PgSearch::Model
    pg_search_scope :search_memo, against: [:memo], ranked_by: "ledger_items.datetime"

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

    enum :status, {
      pending: "pending", # any CPTs contributing to balance
      settled: "settled", # no CPTs contributing to balance or fronted incoming CPT with no CTs
      reversed: "reversed", # sum of CTs is zero
      released: "released", # uncaptured by Stripe (CardCharge only)
      rejected: "rejected", # transfer rejected by ops
      failed: "failed", # error
      canceled: "canceled", # user canceled transfer (for IncreaseCheck this also includes transfers rejected by ops)
      declined: "declined" # CPT has CPDM, no CPTs
    }

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

    def status_text
      status.humanize
    end

    def status_css
      case status.to_sym
      when :pending
        "bg-transparent border border-dashed border-muted m0 mr1"
      when :settled
        nil
      when :reversed
        "bg-info m0 mr1"
      when :released
        "bg-info m0 mr1"
      when :rejected
        "badge m-0 pr-[6px] mr-2 bg-error"
      when :failed
        "badge m-0 pr-[6px] mr-2 bg-error"
      when :canceled
        "badge m-0 pr-[6px] mr-2 bg-error"
      when :declined
        "badge m-0 pr-[6px] mr-2 bg-error"
      end
    end

    # Substring identifiers (case-insensitive) in the memo that indicate an
    # account-verification micro-deposit. Most use "ACCTVERIFY"; a few companies
    # use other variants. Mirrors CanonicalTransaction#likely_account_verification_related?.
    ACCOUNT_VERIFICATION_MEMO_MATCHES = %w[acctverify verify validation sdv-vrfy amts:].freeze

    # Account-verification micro-deposit amounts prove ownership of a linked
    # external account, so they're redacted from non-organizer (transparency)
    # viewers, matching the legacy transactions page. These arrive as raw bank
    # transactions (no linked object) — the Ledger-native equivalent of the
    # legacy HCB-000- code, avoiding a dependency on the old transaction engine.
    def likely_account_verification_related?
      return false unless amount_cents.abs < 100
      return false unless linked_object_type.nil?

      ACCOUNT_VERIFICATION_MEMO_MATCHES.any? { |s| memo.downcase.include?(s) }
    end

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
      amount_cents < 0 && primary_ledger&.receipt_required? && !linked_object_type.in?(["Disbursement::Outgoing", "Reimbursement::ExpensePayout", "StripeServiceFee", "BankFee"])
    end

    def calculate_status
      return :settled if linked_object_type.in?(["Reimbursement::ExpensePayout", "BankFee"])
      return :settled if linked_object_type == "Disbursement::Outgoing" && linked_object.counterparty.canonical_pending_transactions.fronted.any?
      return :settled if linked_object_type.in?(["Disbursement::Outgoing", "Disbursement::Incoming"]) && linked_object.transferred_at.present? && !linked_object.rejected? && !linked_object.errored?
      return :settled if canonical_pending_transactions.fronted.not_declined.revenue.any? && primary_ledger&.can_front_balance?
      return :pending if canonical_pending_transactions.unsettled.exists?

      case linked_object_type
      when "CardCharge"
        return :released if uncaptured_stripe_authorization?

        return :settled
      when "IncreaseCheck" # Increase checks use the same state for users canceling and ops rejecting
        return :canceled if linked_object.try(:rejected?) || linked_object.try(:increase_stopped?) || linked_object.try(:column_stopped?)
      end

      return :rejected if linked_object.try(:rejected?)
      return :failed if linked_object.try(:failed?) || linked_object.try(:errored?)
      return :canceled if linked_object.try(:canceled?) || linked_object.try(:voided?) || linked_object.try(:void_v2?)

      # A declined CPT — determine why it never settled (may have CTs)
      if CanonicalPendingDeclinedMapping.where(canonical_pending_transaction: canonical_pending_transactions).exists?
        return :declined
      elsif canonical_transactions.exists?
        return :reversed if canonical_transactions.sum(:amount_cents).zero?

        return :settled
      end

      # Nothing has mapped to this item yet
      :pending
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

    def fallback_memo
      self.canonical_transactions.first&.try(:smart_memo).presence || self.canonical_pending_transactions.first&.try(:smart_memo).presence || "Transaction"
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
      self.status = calculate_status
      # TODO: only update this when the transaction gets its first CPT and then first CT assigned. currently it updates on every refresh
      self.system_memo = calculate_system_memo
      self.memo = self.custom_memo.presence || self.system_memo.presence || fallback_memo

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
      case linked_object_type
      when "Invoice"
        "Invoice"
      when "Donation"
        "Donation"
      when "AchTransfer"
        "Outgoing ACH"
      when "Wire"
        "Wire"
      when "PaypalTransfer"
        "PayPal transfer"
      when "WiseTransfer"
        "Wise transfer"
      when "Check"
        "Mailed check"
      when "IncreaseCheck"
        "Mailed check"
      when "CheckDeposit"
        "Check deposit"
      when "Disbursement::Outgoing"
        "Outgoing transfer"
      when "Disbursement::Incoming"
        "Incoming transfer"
      when "StripeServiceFee"
        "Stripe service fee"
      when "BankFee"
        "Fiscal sponsorship fee"
      when "FeeRevenue"
        "Fee revenue"
      when "Reimbursement::PayoutHolding"
        "Reimbursement payout holding"
      when "Reimbursement::ExpensePayout"
        "Reimbursement"
      when "CardCharge"
        "Card charge"
      else
        "Bank account transaction"
      end
    end

    def icon
      case linked_object_type
      when "Invoice"
        "payment-docs"
      when "Donation"
        if linked_object.recurring?
          "support-recurring"
        else
          "support"
        end
      when "AchTransfer"
        "payment-transfer"
      when "Wire"
        "web"
      when "PaypalTransfer"
        "paypal"
      when "WiseTransfer"
        "wise"
      when "Check"
        "email"
      when "IncreaseCheck"
        "email"
      when "CheckDeposit"
        "cheque"
      when "Disbursement::Outgoing" # TODO: support for special appearance icons
        if linked_object.card_grant.present?
          "bag"
        else
          "door-leave"
        end
      when "Disbursement::Incoming"
        if linked_object.card_grant.present?
          "bag"
        else
          "door-enter"
        end
      when "StripeServiceFee"
        "cash" # TODO: find unique icon
      when "BankFee"
        "bank-icon"
      when "FeeRevenue"
        "bank-icon"
      when "Reimbursement::PayoutHolding"
        "reimbursement"
      when "Reimbursement::ExpensePayout"
        "reimbursement"
      when "CardCharge"
        linked_object.icon
      else
        "cash"
      end
    end

    def sign
      return :positive if amount_cents.positive?
      return :negative if amount_cents.negative?

      :zero
    end

    private

    # An approved Stripe authorization that never settled was released without
    # capture, as opposed to being declined outright
    def uncaptured_stripe_authorization?
      canonical_transactions.none? && canonical_pending_transactions.any? { |cpt| cpt.raw_pending_stripe_transaction&.stripe_transaction&.dig("approved") }
    end

    def assign_linked_object!
      # Once a linked object is assigned, it should never be changed.
      # In the event of a merger of ledger items (e.g. mapping a CT to an LI with an existing CPT),
      # the ledger item with the CPT will persist, and the ledger item with the CT will be destroyed.
      # No linked objects will be changed.
      return if linked_object.present?

      linked_object = (canonical_pending_transactions.order(date: :asc).map(&:linked_object) + canonical_transactions.order(date: :asc).map(&:linked_object_v2)).compact.first

      update!(linked_object:) if linked_object.present?
    end

  end

end
