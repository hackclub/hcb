# frozen_string_literal: true

# == Schema Information
#
# Table name: raffles
#
#  id                  :bigint           not null, primary key
#  confirmed           :boolean          default(TRUE), not null
#  program             :string           not null
#  ticket_number       :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  referring_raffle_id :bigint
#  user_id             :bigint           not null
#
# Indexes
#
#  index_raffles_on_program_and_user_id  (program,user_id) UNIQUE
#  index_raffles_on_referring_raffle_id  (referring_raffle_id)
#  index_raffles_on_ticket_number        (ticket_number) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (referring_raffle_id => raffles.id)
#  fk_rails_...  (user_id => users.id)
#
class Raffle < ApplicationRecord
  include Hashid::Rails

  TICKET_NUMBER_LENGTH = 6
  REFERRAL_TICKET_TIERS = [1, 2].freeze
  REFERRAL_TICKET_FINAL_TIER = 5

  PROGRAMS_REQUIRING_CONFIRMATION = ["first-worlds-2026-airpods"].freeze
  PROGRAMS_ALLOWING_REFERRALS = ["first-worlds-2026-macbook"].freeze

  belongs_to :user
  has_many :referred_raffle_entries, class_name: "Raffle", foreign_key: "referring_raffle_id", inverse_of: :referring_raffle
  belongs_to :referring_raffle, class_name: "Raffle", optional: true
  validates :program, presence: true
  validates :ticket_number, uniqueness: true, allow_nil: true

  after_save_commit do
    if referring_raffle_id_previously_changed? && referring_raffle.present? && referring_raffle.tier_progress == 0
      RaffleMailer.with(raffle: referring_raffle).extra_ticket_earned.deliver_later
    end
  end

  before_validation do
    self.ticket_number = self.class.generate_ticket_number if self.ticket_number.blank?
  end

  before_validation :default_confirmation_for_program, on: :create

  def self.generate_ticket_number
    high_end = 10**TICKET_NUMBER_LENGTH - 1
    number = SecureRandom.random_number(high_end).to_s.rjust(TICKET_NUMBER_LENGTH, "0")

    return self.generate_ticket_number if self.exists?(ticket_number: number)

    number
  end

  def pending?
    !confirmed?
  end

  def confirm!
    return if confirmed?

    update!(confirmed: true)
  end

  def tickets
    1 + extra_tickets
  end

  def extra_tickets
    referrals = referred_raffle_entries.count
    tickets = 0
    REFERRAL_TICKET_TIERS.each do |t|
      if referrals >= t
        tickets += 1
        referrals -= t
      else
        break
      end
    end
    tickets += referrals.to_i / REFERRAL_TICKET_FINAL_TIER.to_i
    tickets
  end

  def referrals_needed_for_next_ticket
    tix = extra_tickets
    tix > REFERRAL_TICKET_TIERS.length - 1 ? REFERRAL_TICKET_FINAL_TIER : REFERRAL_TICKET_TIERS[tix]
  end

  def tier_progress
    referrals = referred_raffle_entries.count
    tickets = 0
    REFERRAL_TICKET_TIERS.each do |t|
      if referrals >= t
        tickets += 1
        referrals -= t
      else
        break
      end
    end
    if referrals >= REFERRAL_TICKET_FINAL_TIER
      times = referrals.to_i / REFERRAL_TICKET_FINAL_TIER.to_i
      tickets += times
      referrals -= times * REFERRAL_TICKET_FINAL_TIER
    end
    referrals
  end

  def referral_link
    return Rails.application.routes.url_helpers.welcome_first_index_url(referred_by: self.hashid) if program_allows_referrals? && user_allows_referrals?

    nil
  end

  def program_allows_referrals?
    PROGRAMS_ALLOWING_REFERRALS.include? program
  end

  def user_allows_referrals?
    user.verified?
  end

  private

  def default_confirmation_for_program
    self.confirmed = false if PROGRAMS_REQUIRING_CONFIRMATION.include?(program)
  end

end
