# frozen_string_literal: true

# == Schema Information
#
# Table name: reimbursement_expenses
#
#  id                      :bigint           not null, primary key
#  aasm_state              :string
#  amount_cents            :integer          default(0), not null
#  approved_at             :datetime
#  category                :integer
#  deleted_at              :datetime
#  description             :text
#  expense_number          :integer          not null
#  memo                    :text
#  type                    :string
#  value                   :decimal(, )      default(0.0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  approved_by_id          :bigint
#  reimbursement_report_id :bigint           not null
#
# Indexes
#
#  index_reimbursement_expenses_on_approved_by_id           (approved_by_id)
#  index_reimbursement_expenses_on_reimbursement_report_id  (reimbursement_report_id)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (reimbursement_report_id => reimbursement_reports.id)
#
module Reimbursement
  class Expense < ApplicationRecord
    belongs_to :report, inverse_of: :expenses, foreign_key: "reimbursement_report_id", touch: true
    monetize :amount_cents, as: "amount", with_model_currency: :currency
    validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
    attribute :expense_number, :integer
    has_one :expense_payout
    has_one :event, through: :report
    has_one :user, through: :report
    belongs_to :approved_by, class_name: "User", optional: true
    include AASM
    include Receiptable
    include Hashid::Rails
    has_paper_trail
    acts_as_paranoid

    scope :to_sum, -> { where.not(type: Reimbursement::Expense::Fee.name) }

    include PublicIdentifiable
    set_public_id_prefix :rme

    include PublicActivity::Model
    tracked owner: proc{ |controller, record| controller&.current_user }, recipient: proc { |controller, record| record.user }, event_id: proc { |controller, record| record.event.id }, only: []

    before_validation :set_amount_cents

    validates :expense_number, uniqueness: { scope: :reimbursement_report_id }
    validate :valid_expense_type

    enum :category, {
      "Advertising / Marketing": 7000,
      "Customs Fees": 7031,
      "Dues & Subscriptions": 7042,
      "Equipment & Furniture": 7053,
      "Food & Entertainment": 8130,
      "Gifts": 8805,
      "Janitorial & Maintenance": 7050,
      "Mileage": 8120,
      "Office Supplies": 7044,
      "Postage & Shipping": 7047,
      "Prizes": 7030,
      "Project Supplies": 7034,
      "Software": 7045,
      "Taxes & Licenses": 7041,
      "Technical Infrastructure": 7035,
      "Training": 8150,
      "Travel": 8110
    }, instance_methods: false

    before_validation do
      unless self.expense_number
        self.expense_number = (self.report.expenses.with_deleted.pluck(:expense_number).max || 0) + 1
      end
    end

    include TouchHistory

    broadcasts_refreshes_to ->(expense) { expense.was_touched? ? :_noop : expense.report }

    scope :complete, -> { where.not(memo: nil, amount_cents: 0).merge(self.with_receipt) }

    aasm do
      state :pending, initial: true
      state :approved

      event :mark_approved do
        transitions from: :pending, to: :approved
        after do |current_user|
          if report.team_review_required? && current_user
            update(approved_by: current_user)
            create_activity(key: "reimbursement_expense.approved", owner: current_user)
          end

        end
      end

      event :mark_pending do
        transitions from: :approved, to: :pending
        after do |current_user|
          update(approved_by: current_user) if current_user
        end
      end
    end

    before_update do
      if approved? && (memo_changed? || amount_cents_changed? || category_changed? || description_changed?)
        mark_pending!
        self.approved_by = nil
      end
    end

    def receipt_required?
      true
    end

    def marked_no_or_lost_receipt_at
      nil
    end

    def missing_receipt?
      # Method needs to be defined for receiptable
      true
    end

    def rejected?
      report.rejected? || pending? && report.closed?
    end

    # multiplier for value -> amount_cents
    def rate
      Money.from_amount(1, currency).cents
    end

    delegate :conversion_rate, to: :report

    def value_label
      label = "Amount"
      label += " (#{currency})" unless currency == "USD"
      label
    end

    def set_amount_cents
      self.amount_cents = (rate * value).round
    end

    def is_standard?
      type.nil? || type == "Reimbursement::Expense"
    end

    def is_fee?
      type == "Reimbursement::Expense::Fee"
    end

    def is_mileage?
      type == "Reimbursement::Expense::Mileage"
    end

    delegate :currency, to: :report

    def card_label
      return memo + " (#{ApplicationController.helpers.render_money(amount_cents)})" if memo && !is_standard?

      memo
    end

    def policy_class
      Reimbursement::ExpensePolicy
    end

    delegate :locked?, to: :report

    def status_color
      return "muted" if pending? && report.draft?
      return "primary" if rejected?
      return "warning" if pending? || report.reversed?

      "success"
    end

    def valid_expense_type
      unless type.nil? || [Reimbursement::Expense.name, Reimbursement::Expense::Mileage.name, Reimbursement::Expense::Fee.name].include?(type)
        errors.add(:type, "must be a valid expense type.")
      end
    end

    before_validation do
      if self.type.nil?
        self.type = Reimbursement::Expense.name
      end
    end

  end
end
