# frozen_string_literal: true

# == Schema Information
#
# Table name: reimbursement_expense_payouts
#
#  id                               :bigint           not null, primary key
#  aasm_state                       :string
#  amount_cents                     :integer          not null
#  hcb_code                         :string
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  event_id                         :bigint           not null
#  reimbursement_expenses_id        :bigint           not null
#  reimbursement_payout_holdings_id :bigint
#
# Indexes
#
#  index_expense_payouts_on_expense_payout_holdings_id  (reimbursement_payout_holdings_id)
#  index_expense_payouts_on_expenses_id                 (reimbursement_expenses_id)
#  index_reimbursement_expense_payouts_on_event_id      (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
module Reimbursement
  class ExpensePayout < ApplicationRecord
    has_paper_trail

    include AASM
    include HasBookTransfer

    belongs_to :event
    belongs_to :expense, foreign_key: "reimbursement_expenses_id", inverse_of: :expense_payout
    belongs_to :payout_holding, optional: true, foreign_key: "reimbursement_payout_holdings_id", inverse_of: :expense_payouts

    monetize :amount_cents

    after_create :set_and_create_hcb_code

    validate :expense_approved, on: :create
    validate :expense_report_approved, on: :create

    belongs_to :local_hcb_code, foreign_key: "hcb_code", primary_key: "hcb_code", class_name: "HcbCode", inverse_of: :reimbursement_expense_payout, optional: true
    has_many :canonical_transactions, through: :local_hcb_code
    has_one :canonical_pending_transaction, foreign_key: "reimbursement_expense_payout_id", inverse_of: :reimbursement_expense_payout

    scope :in_transit_or_pending, -> { where("aasm_state in (?)", ["pending", "in_transit"]) }

    after_create do
      CanonicalPendingTransaction.create!(reimbursement_expense_payout: self, event:, amount_cents:, memo: expense.memo, date: created_at, fronted: true)
    end

    aasm do
      state :pending, initial: true
      state :in_transit
      state :settled
      state :reversed

      event :mark_in_transit do
        transitions from: :pending, to: :in_transit
      end

      event :mark_settled do
        transitions from: :in_transit, to: :settled
      end

      event :mark_reversed do
        transitions from: :settled, to: :reversed
      end
    end

    validate do
      if Reimbursement::ExpensePayout.where(reimbursement_expenses_id:).excluding(self).any?
        errors.add(:base, "A reimbursement expense can only have one expense payout.")
      end
    end

    def state
      return :success if settled?
      return :info if in_transit?

      :muted
    end

    def state_text
      return "Paid & Settled" if settled?
      return "Paid & Settling" if in_transit?

      "Pending"
    end

    def reverse!
      raise ArgumentError, "must be a settled expense payout" unless settled?

      ActiveRecord::Base.transaction do

        mark_reversed!

        canonical_pending_transaction.decline!

        # these are reversed because this is reverse!
        sender_bank_account_id = ColumnService::Accounts.id_of(book_transfer_receiving_account)
        receiver_bank_account_id = ColumnService::Accounts.id_of(book_transfer_originating_account)

        ColumnService.post "/transfers/book",
                           amount: amount_cents.abs,
                           currency_code: "USD",
                           sender_bank_account_id:,
                           receiver_bank_account_id:,
                           description: "HCB-#{local_hcb_code.short_code}"
      end

      true
    end

    private

    def set_and_create_hcb_code
      self.update_column(:hcb_code, "HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::EXPENSE_PAYOUT_CODE}-#{id}")
      HcbCode.find_or_create_by(hcb_code:)
    end

    def expense_approved = expense.approved?
    def expense_report_approved = expense.report.reimbursement_approved?

  end
end
