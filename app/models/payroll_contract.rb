# frozen_string_literal: true

# == Schema Information
#
# Table name: payroll_contracts
#
#  id                :bigint           not null, primary key
#  ends_on           :date             not null
#  hourly_rate_cents :integer          not null
#  purpose           :string           not null
#  starts_on         :date             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  payee_id          :bigint           not null
#
# Indexes
#
#  index_payroll_contracts_on_payee_id  (payee_id)
#
# Foreign Keys
#
#  fk_rails_...  (payee_id => payees.id)
#
class PayrollContract < ApplicationRecord
  include PgSearch::Model

  belongs_to :payee
  has_one :event, through: :payee
  has_one :legal_entity, through: :payee

  has_one_attached :file

  monetize :hourly_rate_cents

  # A contract may run for at most one year and may not be scheduled to start
  # more than six months out from today.
  MAX_DURATION = 1.year
  MAX_START_LEAD_TIME = 6.months

  validates :starts_on, :ends_on, :purpose, presence: true
  validate :ends_on_after_starts_on
  validate :duration_within_limit
  validate :starts_on_within_lead_time

  pg_search_scope :search_recipient, associated_against: { payee: [:display_name, :email] }, using: { tsearch: { prefix: true, dictionary: "english" } }

  delegate :display_name, :email, :total_paid_cents, to: :payee

  # Onboarding until the contractor has completed sign-up (tax forms /
  # payout method), then Active while the contract runs, and Completed once
  # the contract period has ended.
  def status
    return :onboarding if legal_entity.nil?
    return :completed if ends_on < Date.current

    :active
  end

  def status_text
    status.to_s.humanize
  end

  def status_color
    case status
    when :active then "success"
    when :onboarding then "info"
    else "muted"
    end
  end

  # Renders the contract window like "Jan–Jun 2026", collapsing to a single
  # month ("Apr 2026") or spanning years ("Dec 2025–Feb 2026") when needed.
  def period_label
    return if starts_on.nil?

    return starts_on.strftime("%b %Y") if ends_on.nil? || (starts_on.month == ends_on.month && starts_on.year == ends_on.year)

    if starts_on.year == ends_on.year
      "#{starts_on.strftime("%b")}–#{ends_on.strftime("%b %Y")}"
    else
      "#{starts_on.strftime("%b %Y")}–#{ends_on.strftime("%b %Y")}"
    end
  end

  private

  def ends_on_after_starts_on
    return if starts_on.blank? || ends_on.blank?

    errors.add(:ends_on, "must be after the start date") if ends_on < starts_on
  end

  def duration_within_limit
    return if starts_on.blank? || ends_on.blank?

    errors.add(:ends_on, "can't be more than one year after the start date") if ends_on > starts_on + MAX_DURATION
  end

  def starts_on_within_lead_time
    return if starts_on.blank?

    errors.add(:starts_on, "can't be more than six months from today") if starts_on > Date.current + MAX_START_LEAD_TIME
  end

end
