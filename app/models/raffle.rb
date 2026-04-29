# frozen_string_literal: true

# == Schema Information
#
# Table name: raffles
#
#  id            :bigint           not null, primary key
#  confirmed     :boolean          default(TRUE), not null
#  program       :string           not null
#  ticket_number :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_raffles_on_program_and_user_id  (program,user_id) UNIQUE
#  index_raffles_on_ticket_number        (ticket_number) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Raffle < ApplicationRecord
  TICKET_NUMBER_LENGTH = 6

  PROGRAMS_REQUIRING_CONFIRMATION = ["first-worlds-2026-airpods"].freeze

  belongs_to :user
  validates :program, presence: true
  validates :ticket_number, uniqueness: true, allow_nil: true

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

  private

  def default_confirmation_for_program
    self.confirmed = false if PROGRAMS_REQUIRING_CONFIRMATION.include?(program)
  end

end
