# frozen_string_literal: true

# == Schema Information
#
# Table name: employee_payments
#
#  id             :bigint           not null, primary key
#  aasm_state     :string
#  amount_cents   :integer          default(0), not null
#  approved_at    :datetime
#  description    :text
#  payout_type    :string
#  rejected_at    :datetime
#  review_message :text
#  title          :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  employee_id    :bigint           not null
#  payout_id      :bigint
#  reviewed_by_id :bigint
#
# Indexes
#
#  index_employee_payments_on_employee_id     (employee_id)
#  index_employee_payments_on_reviewed_by_id  (reviewed_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (employee_id => employees.id)
#
class Employee
  class Payment < ApplicationRecord
    include AASM

    include PublicActivity::Model
    tracked owner: proc{ |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.employee.event.id }, only: [:create]

    belongs_to :payout, polymorphic: true, optional: true

    belongs_to :employee

    belongs_to :reviewed_by, class_name: "User", optional: true
    validates_presence_of :reviewed_by, unless: -> { submitted? }

    has_one :receipt, as: :receiptable
    alias_method :invoice, :receipt

    monetize :amount_cents

    has_paper_trail

    aasm timestamps: true do
      state :submitted, initial: true
      state :approved
      state :paid
      state :rejected
      state :failed

      event :mark_approved do
        transitions from: :submitted, to: :approved
        after do
          update!(payout: nil)
        end
      end

      event :mark_paid do
        transitions from: :approved, to: :paid
        after do
          Employee::PaymentMailer.with(payment: self).approved.deliver_later
          create_activity(key: "employee_payment.paid", owner: employee.user)
        end
      end

      event :mark_rejected do
        transitions from: [:failed, :submitted], to: :rejected
        after do |send_email: true|
          Employee::PaymentMailer.with(payment: self).rejected.deliver_later if send_email
        end
      end

      event :mark_failed do
        transitions from: :paid, to: :failed
        after do |reason: nil|
          Employee::PaymentMailer.with(payment: self, reason:).failed.deliver_later
        end
      end
    end

    after_create_commit do
      Employee::PaymentMailer.with(payment: self).review_requested.deliver_later
    end

    def state_color
      return "error" if rejected?
      return "warning" if failed?
      return "info" if submitted?

      "success"
    end

    def payout_method_name
      return "ACH transfer" if payout.is_a?(AchTransfer)
      return "PayPal transfer" if payout.is_a?(PaypalTransfer)
      return "Mailed check" if payout.is_a?(IncreaseCheck)

      "Unknown"
    end

    def previously_paid?
      versions.where_object_changes_to(aasm_state: "paid").any?
    end

  end

end
