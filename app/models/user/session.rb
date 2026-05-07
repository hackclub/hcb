# frozen_string_literal: true

# == Schema Information
#
# Table name: user_sessions
#
#  id                       :bigint           not null, primary key
#  device_info              :string
#  expiration_at            :datetime         not null
#  fingerprint              :string
#  ip                       :string
#  last_seen_at             :datetime
#  latitude                 :decimal(, )
#  longitude                :decimal(, )
#  os_info                  :string
#  session_token_bidx       :string
#  session_token_ciphertext :text
#  signed_out_at            :datetime
#  timezone                 :string
#  verified                 :boolean          default(FALSE), not null
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
class User
  class Session < ApplicationRecord
    has_paper_trail skip: [:session_token] # ciphertext columns will still be tracked
    has_encrypted :session_token
    blind_index :session_token

    belongs_to :user, optional: true
    belongs_to :impersonated_by, class_name: "User", optional: true
    belongs_to :webauthn_credential, optional: true
    has_many :logins, foreign_key: "user_session_id", inverse_of: :user_session
    has_many :referral_attributions, class_name: "Referral::Attribution", foreign_key: "user_session_id", inverse_of: :user_session

    validate :verified_matches_user_verified

    include PublicActivity::Model

    scope :impersonated, -> { where.not(impersonated_by_id: nil) }
    scope :not_impersonated, -> { where(impersonated_by_id: nil) }
    scope :expired, -> { where("expiration_at <= ?", Time.now) }
    scope :not_expired, -> { where("expiration_at > ?", Time.now) }
    scope :recently_expired_within, ->(date) { expired.where("expiration_at >= ?", date) }
    scope :verified, -> { where(verified: true) }
    scope :unverified, -> { where(verified: false) }

    after_save :create_login_activity, if: -> { user_id_before_last_save.nil? && user(allow_unverified: true).present? }

    after_create_commit do
      next if impersonated?
      next unless user.present?
      next unless user.user_sessions.size > 1
      next unless fingerprint.present?
      next unless user.user_sessions.excluding(self).where(fingerprint:).none?

      User::SessionMailer.new_login(user_session: self).deliver_later
    end

    extend Geocoder::Model::ActiveRecord
    geocoded_by :ip
    after_validation :geocode, if: ->(session){ session.ip.present? and session.ip_changed? }

    validate :user_is_unlocked, on: :create

    def impersonated?
      !impersonated_by.nil?
    end

    LAST_SEEN_AT_COOLDOWN = 5.minutes

    MAX_SESSION_DURATION = 3.weeks
    MAX_UNVERIFIED_SESSION_DURATION = 7.days

    def update_session_timestamps
      return if last_seen_at&.after? LAST_SEEN_AT_COOLDOWN.ago # prevent spamming writes

      underlying_user = user(allow_unverified: true)
      if unverified? && underlying_user&.verified?
        # Zombie session — invariant violation that should never occur (see
        # `verified_matches_user_verified` validation and the
        # `sign_out_unverified_sessions` callback in User). If we hit one
        # anyway, actively revoke it instead of letting it linger to natural
        # expiry.
        update_columns(signed_out_at: Time.now, expiration_at: Time.now)
        return
      end

      updates = { last_seen_at: Time.now }
      unless impersonated?
        effective_max = unverified? ? MAX_UNVERIFIED_SESSION_DURATION : MAX_SESSION_DURATION
        preference = (underlying_user || User.new).session_validity_preference.seconds.from_now
        updates[:expiration_at] = [created_at + effective_max, preference].min
      end
      update_columns(**updates)
    end

    def expired?
      expiration_at <= Time.now
    end

    SUDO_MODE_TTL = 2.hours

    # Determines whether the user can perform a sensitive action without
    # reauthenticating.
    #
    # @return [Boolean]
    def sudo_mode?
      return true unless Flipper.enabled?(:sudo_mode_2015_07_21, user)

      return false if last_authenticated_at.nil?

      last_authenticated_at >= SUDO_MODE_TTL.ago
    end

    def clear_metadata!
      update!(
        device_info: nil,
        latitude: nil,
        longitude: nil,
      )
    end

    def last_reauthenticated_at
      logins.complete.reauthentication.max_by(&:created_at)&.created_at
    end

    def user(allow_unverified: false)
      return nil unless verified? || allow_unverified

      super()
    end

    def unverified_user
      return nil if verified?

      user(allow_unverified: true)
    end

    def unverified?
      !verified?
    end

    private

    def verified_matches_user_verified
      # Bypass the `User::Session#user` override (which returns nil for
      # unverified sessions) so we can compare against the actual associated
      # user regardless of session-verification state.
      actual_user = association(:user).load_target
      return if actual_user.nil?

      if verified? && !actual_user.verified?
        errors.add(:verified, "session cannot be verified for an unverified user")
      elsif !verified? && actual_user.verified?
        errors.add(:verified, "session cannot be unverified for a verified user")
      end
    end

    def user_is_unlocked
      if user&.locked? && !impersonated?
        errors.add(:user, "Your HCB account has been locked.")
      end
    end

    # The last time the user went through a login flow. Used to determine whether
    # sensitive actions can be performed.
    #
    # @return [ActiveSupport::TimeWithZone, nil]
    def last_authenticated_at
      logins.complete.max_by(&:created_at)&.created_at
    end

    def create_login_activity
      activity_user = impersonated_by || user(allow_unverified: true)
      create_activity key: "user_session.create", owner: activity_user, recipient: activity_user
    end

  end

end
