# frozen_string_literal: true

# == Schema Information
#
# Table name: user_sessions
#
#  id                       :bigint           not null, primary key
#  deleted_at               :datetime
#  device_info              :string
#  expiration_at            :datetime         not null
#  fingerprint              :string
#  ip                       :string
#  last_seen_at             :datetime
#  latitude                 :decimal(, )
#  longitude                :decimal(, )
#  os_info                  :string
#  peacefully_expired       :boolean
#  session_token_bidx       :string
#  session_token_ciphertext :text
#  timezone                 :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  impersonated_by_id       :bigint
#  user_id                  :bigint
#  webauthn_credential_id   :bigint
#
# Indexes
#
#  index_user_sessions_on_impersonated_by_id      (impersonated_by_id)
#  index_user_sessions_on_session_token_bidx      (session_token_bidx)
#  index_user_sessions_on_user_id                 (user_id)
#  index_user_sessions_on_webauthn_credential_id  (webauthn_credential_id)
#
# Foreign Keys
#
#  fk_rails_...  (impersonated_by_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class UserSession < ApplicationRecord
  has_paper_trail skip: [:session_token] # ciphertext columns will still be tracked
  has_encrypted :session_token
  blind_index :session_token

  acts_as_paranoid

  belongs_to :user
  belongs_to :impersonated_by, class_name: "User", optional: true
  belongs_to :webauthn_credential, optional: true
  has_one :login_token, required: false

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| record.user }, recipient: proc { |controller, record| record.user }, only: [:create]

  scope :impersonated, -> { where.not(impersonated_by_id: nil) }
  scope :not_impersonated, -> { where(impersonated_by_id: nil) }

  # PEACEFUL VS UNPEACEFUL EXPIRATIONS
  # This is used to help determine if a user session's data (ip, etc.) can be
  # "trusted". Trusted sessions (peaceful sessions) are then used to determine
  # whether to relax or strength security measures for a user.
  #
  # Example use case:
  #   Only allow a user to use a magic login link IF the browser's IP was
  #   previously used by a trusted session.
  #
  # Implementation details:
  #   Sessions are considered unpeaceful if there is a chance the session may
  #   have been hijacked. These peaceful/unpeaceful classifications should be
  #   taken with a grain of salt since they're speculations and will have a lot
  #   of false "unpeaceful" sessions. So, it's probably best to use peaceful
  #   sessions to relax security measures, rather than use unpeaceful sessions
  #   to strengthen them.
  #
  #   - Peaceful
  #     - Normal sign out of current session
  #     - Normal time-based expiration
  #   - Unpeaceful
  #     - Sign out of all sessions
  #     - Sign out of a specific session
  #
  #
  # In order to use the following `peacefully_expired` scopes, you should also
  # use `act_as_paranoid`'s `only_deleted` scope since theoretically, a session
  # can only be peacefully_expired once it has been deleted.
  scope :peacefully_expired, -> { where(peacefully_expired: true) }
  scope :not_peacefully_expired, -> { where.not(peacefully_expired: true) }

  after_create_commit do
    if fingerprint.present? && user.user_sessions.excluding(self).where(fingerprint:).none?
      UserSessionMailer.new_login(user_session: self).deliver_later
    end
  end

  extend Geocoder::Model::ActiveRecord
  geocoded_by :ip
  after_validation :geocode, if: ->(session){ session.ip.present? and session.ip_changed? }

  validate :user_is_unlocked, on: :create

  def impersonated?
    !impersonated_by.nil?
  end

  def set_as_peacefully_expired
    # Don't let this raise exceptions, otherwise users can't sign out
    begin
      update(peacefully_expired: true)
    rescue => e
      Airbrake.notify e, session: self
      Rails.logger.error "Error setting session as peacefully expired: #{e.message}"
    end

    # Return self to allow chaining
    self
  end

  LAST_SEEN_AT_COOLDOWN = 5.minutes
  def touch_last_seen_at
    return if last_seen_at&.after? LAST_SEEN_AT_COOLDOWN.ago # prevent spamming writes

    update_columns(last_seen_at: Time.now)
  end

  private

  def user_is_unlocked
    if user.locked? && !impersonated?
      errors.add(:user, "Your HCB account has been locked.")
    end
  end

end
