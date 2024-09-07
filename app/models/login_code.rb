# frozen_string_literal: true

# == Schema Information
#
# Table name: login_codes
#
#  id         :bigint           not null, primary key
#  code       :text
#  ip_address :inet
#  used_at    :datetime
#  user_agent :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_login_codes_on_code     (code)
#  index_login_codes_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class LoginCode < ApplicationRecord
  EXPIRATION = 15.minutes

  scope :active, -> { where(used_at: nil, created_at: EXPIRATION.ago..) }

  belongs_to :user

  after_initialize :generate_code

  validates :code, presence: true, uniqueness: { conditions: -> { active } }

  # "123456" -> "123-456"
  def pretty
    code&.scan(/.../)&.join("-")
  end

  def active?
    used_at.nil? && created_at >= EXPIRATION.ago
  end

  private

  def generate_code
    return if code.present?

    loop do
      self.code = SecureRandom.random_number(999_999).to_s.ljust(6, "0") # pad with zero(s) if needed
      self.validate
      break unless self.errors[:code].any?
    end
  end

end
