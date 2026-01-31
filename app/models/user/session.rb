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
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  impersonated_by_id       :bigint
#  user_id                  :bigint           not null
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

    belongs_to :user
    belongs_to :impersonated_by, class_name: "User", optional: true
    belongs_to :webauthn_credential, optional: true
    has_many :logins, foreign_key: "user_session_id", inverse_of: :user_session

    include PublicActivity::Model
    tracked owner: proc{ |controller, record| record.impersonated_by || record.user }, recipient: proc { |controller, record| record.impersonated_by || record.user }, only: [:create]

    scope :impersonated, -> { where.not(impersonated_by_id: nil) }
    scope :not_impersonated, -> { where(impersonated_by_id: nil) }
    scope :expired, -> { where("expiration_at <= ?", Time.now) }
    scope :not_expired, -> { where("expiration_at > ?", Time.now) }
    scope :recently_expired_within, ->(date) { expired.where("expiration_at >= ?", date) }

    after_create_commit do
      next if impersonated?
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

    def update_session_timestamps
      return if last_seen_at&.after? LAST_SEEN_AT_COOLDOWN.ago # prevent spamming writes

      updates = { last_seen_at: Time.now }
      updates[:expiration_at] = [created_at + MAX_SESSION_DURATION, user.session_validity_preference.seconds.from_now].min unless impersonated?
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

    private

    def user_is_unlocked
      if user.locked? && !impersonated?
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

  end

end
