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
#  signed_out_at            :datetime
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

  belongs_to :user
  belongs_to :impersonated_by, class_name: "User", optional: true
  belongs_to :webauthn_credential, optional: true

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| record.impersonated_by || record.user }, recipient: proc { |controller, record| record.impersonated_by || record.user }, only: [:create]

  scope :impersonated, -> { where.not(impersonated_by_id: nil) }
  scope :not_impersonated, -> { where(impersonated_by_id: nil) }
  scope :expired, -> { where("expiration_at <= ?", Time.now) }
  scope :not_expired, -> { where("expiration_at > ?", Time.now) }
  scope :recently_expired_within, ->(date) { expired.where("coalesce(deleted_at, expiration_at) >= ?", date) }

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
