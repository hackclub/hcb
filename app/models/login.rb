# frozen_string_literal: true

# == Schema Information
#
# Table name: logins
#
#  id                       :bigint           not null, primary key
#  aasm_state               :string
#  authentication_factors   :jsonb
#  browser_token_ciphertext :text
#  is_reauthentication      :boolean          default(FALSE), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  referral_link_id         :bigint
#  referral_program_id      :bigint
#  user_id                  :bigint           not null
#  user_session_id          :bigint
#
# Indexes
#
#  index_logins_on_referral_link_id     (referral_link_id)
#  index_logins_on_referral_program_id  (referral_program_id)
#  index_logins_on_user_id              (user_id)
#  index_logins_on_user_session_id      (user_session_id)
#
class Login < ApplicationRecord
  self.ignored_columns = ["referral_program_id"]

  include AASM
  include Hashid::Rails

  belongs_to :user
  belongs_to :user_session, class_name: "User::Session", optional: true

  scope(:initial, -> { where(is_reauthentication: false) })
  scope(:reauthentication, -> { where(is_reauthentication: true) })

  belongs_to :referral_link, class_name: "Referral::Link", optional: true

  has_encrypted :browser_token
  before_validation :ensure_browser_token

  store_accessor :authentication_factors, :sms, :email, :webauthn, :totp, :backup_code, prefix: :authenticated_with

  EXPIRATION = 15.minutes

  scope :active, -> { where(created_at: EXPIRATION.ago..) }

  has_paper_trail skip: [:browser_token]

  validate do
    if user_session.present? && !complete?
      # how did we create session when it's not complete?!
      Rails.error.unexpected "An incomplete login #{id} has a session #{user_session.id} present."
      errors.add(:base, "An incomplete login has a session present.")
    end
  end

  validate do
    if user_session.present? && user_session.user != user
      Rails.error.unexpected "A login with a session present has a session.user (#{session.user.id}) / user (#{user.id}) mismatch."
      errors.add(:base, "A login with a session present has a session.user / user mismatch.")
    end
  end

  aasm do
    state :incomplete, initial: true
    state :complete

    event :mark_complete do
      transitions from: :incomplete, to: :complete do
        guard do
          authentication_factors_count == required_authentication_factors_count
        end
      end
    end
  end

  before_save do
    mark_complete! if may_mark_complete?
  end

  before_create(:sync_is_reauthentication)

  def authentication_factors_count
    return 0 if authentication_factors.nil?

    authentication_factors.values.count(true)
  end

  def ensure_browser_token
    # Avoid generating a new token if one is already encrypted
    return if self[:browser_token_ciphertext].present?

    self.browser_token ||= SecureRandom.base58(24)
  end

  def email_available?
    !authenticated_with_email
  end

  def sms_available?
    !authenticated_with_sms && user.phone_number_verified
  end

  def webauthn_available?
    !authenticated_with_webauthn && user.webauthn_credentials.any?
  end

  def totp_available?
    !authenticated_with_totp && user.totp.present?
  end

  def backup_code_available?
    !authenticated_with_backup_code && user.backup_codes_enabled?
  end

  def available_factors
    factors = []
    factors << :sms if sms_available?
    factors << :email if email_available?
    factors << :webauthn if webauthn_available?
    factors << :totp if totp_available?
    factors << :backup_code if backup_code_available?
    factors
  end

  def reauthentication?
    is_reauthentication?
  end

  private

  # The number of authentication factors required to consider this login
  # complete (based on the user's 2FA setting and whether this is a
  # reauthentication)
  #
  # @return [Integer]
  def required_authentication_factors_count
    if user.use_two_factor_authentication? && !reauthentication?
      2
    else
      1
    end
  end

  def sync_is_reauthentication
    self.is_reauthentication = reauthentication?
  end

end
