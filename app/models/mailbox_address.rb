# frozen_string_literal: true

# == Schema Information
#
# Table name: mailbox_addresses
#
#  id           :bigint           not null, primary key
#  aasm_state   :string
#  address      :string           not null
#  discarded_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_mailbox_addresses_on_address  (address) UNIQUE
#  index_mailbox_addresses_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class MailboxAddress < ApplicationRecord
  DISCRIMINATOR_LENGTH = 4 # currently, 4 is enough to avoid most collisions, however this can be increased later
  EMAIL_DOMAIN = "hcb.gg"

  VALIDATION_REGEX = /\A[a-z]+\.\d{#{DISCRIMINATOR_LENGTH}}@#{Regexp.escape(EMAIL_DOMAIN)}\z/

  belongs_to :user
  validates :user, uniqueness: { scope: [:aasm_state, :user_id, :discarded_at], message: "can only have one mailbox address previewed/active at a time" }

  validates :address, presence: true, uniqueness: true, email_with_tld: true
  validates :address, format: { with: VALIDATION_REGEX, message: "must conform to correct format" }

  before_validation do
    self.address = self.class.generate_address if self.address.blank?
  end

  include AASM

  aasm timestamps: true do
    state :previewed, initial: true
    state :activated, :discarded

    event :mark_activated do
      transitions from: :previewed, to: :activated
    end

    event :mark_discarded do
      transitions from: :activated, to: :discarded
    end
  end

  def identifier
    address.split("@")&.first
  end

  def domain
    address.split("@")&.last
  end

  def self.generate_address
    high_end = 10**DISCRIMINATOR_LENGTH - 1
    discriminator = rand(1..high_end).to_s.rjust(DISCRIMINATOR_LENGTH, "0")

    animal = Faker::Creature::Animal.name.downcase.gsub(/[^a-z]/, "")

    identifier = "#{animal}.#{discriminator}"
    address = "#{identifier}@#{EMAIL_DOMAIN}"

    return self.generate_address if self.exists?(address:)

    address
  end

end
