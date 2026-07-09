# frozen_string_literal: true

# == Schema Information
#
# Table name: payroll_positions
#
#  id            :bigint           not null, primary key
#  aasm_state    :string           not null
#  currency      :string           default("USD"), not null
#  description   :text             not null
#  end_date      :date             not null
#  onboarded_at  :datetime
#  onboarding_at :datetime
#  rate_cents    :integer          default(0), not null
#  rejected_at   :datetime
#  start_date    :date             not null
#  terminated_at :datetime
#  title         :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  payee_id      :bigint           not null
#
# Indexes
#
#  index_payroll_positions_on_payee_id  (payee_id)
#
# Foreign Keys
#
#  fk_rails_...  (payee_id => payees.id)
#
module Payroll
  class Position < ApplicationRecord
    include AASM
    include Contractable

    has_paper_trail

    belongs_to :payee

    has_many :invoices, class_name: "Payroll::Invoice", foreign_key: "payroll_position_id", inverse_of: :payroll_position, dependent: :destroy
    has_one :event, through: :payee
    has_one :contract_event, through: :payee, source: :event # a requirement of Contractable

    has_one_attached :file
    validates :file, size: { less_than_or_equal_to: 25.megabytes }, if: -> { attachment_changes["file"].present? }

    monetize :rate_cents, with_model_currency: :currency

    after_create_commit do
      Payroll::Position::ExpireJob.set(wait_until: end_date.end_of_day).perform_later(self)
    end

    validates :currency, inclusion: { in: Money::Currency.all.map(&:iso_code) }
    validate :end_date_after_start_date
    validate :start_date_within_six_months
    validate :duration_within_one_year

    aasm timestamps: true do
      state :under_review, initial: true
      state :onboarding
      state :onboarded
      state :expired
      state :rejected
      state :terminated

      event :mark_onboarding do
        transitions from: :under_review, to: :onboarding
      end

      event :mark_rejected do
        transitions from: [:under_review, :onboarding], to: :rejected
      end

      event :mark_onboarded do
        transitions from: :onboarding, to: :onboarded
      end

      event :mark_expired do
        transitions from: :onboarded, to: :expired
      end

      event :mark_terminated do
        transitions from: :onboarded, to: :terminated
      end
    end

    private

    def end_date_after_start_date
      return if start_date.blank? || end_date.blank?

      errors.add(:end_date, "must be after the start date") if end_date <= start_date
    end

    def start_date_within_six_months
      errors.add(:start_date, "cannot be more than 6 months in the future") if start_date > 6.months.from_now.to_date
    end

    def duration_within_one_year
      errors.add(:end_date, "cannot be more than 1 year after the start date") if end_date > start_date + 1.year
    end

  end
end
