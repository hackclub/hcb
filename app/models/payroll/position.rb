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
    validates :file, size: { less_than_or_equal_to: 25.megabytes }, content_type: [:pdf], if: -> { attachment_changes["file"].present? }

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

    def send_contract(organizer_user: nil, cosigner_email: nil, reissue_messages: {}, reissue_of: nil, **options)
      contract = nil
      organizer_user ||= reissue_of&.party(:organizer)&.user
      raise ArgumentError, "an organizer is required to send a payroll contract" if organizer_user.nil?

      ActiveRecord::Base.transaction do
        contract = Contract::PayrollPosition.create!(
          contractable: self,
          include_videos: false,
          external_template_id: Contract::PayrollPosition::DOCUSEAL_TEMPLATE_ID,
          prefills: {
            "payee_name"  => payee.display_name,
            "title"       => title,
            "description" => description,
            "rate"        => rate.format,
            "start_date"  => start_date.to_fs(:long),
            "end_date"    => end_date.to_fs(:long),
            "documents"   => (file.attached? ? [{ "name" => file.blob.filename.to_s, "file" => Rails.application.routes.url_helpers.rails_blob_url(file) }] : nil)
          }.compact,
          reissue_of:
        )
        contract.parties.create!(user: organizer_user, role: :organizer)
        contract.parties.create!(user: contractor_user, external_email: payee.email, role: :contractor)
      end

      contract.send!(reissue_messages:)

      contract
    end


    def on_contract_voided(contract)
      mark_rejected! if may_mark_rejected?
    end

    def contract_redirect_path
      Rails.application.routes.url_helpers.my_payroll_path
    end

    def contract_notify_hcb?
      false
    end

    private

    def contractor_user
      User.find_by(email: payee.email)
    end

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
