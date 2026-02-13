# frozen_string_literal: true

# == Schema Information
#
# Table name: api_tokens
#
#  id               :bigint           not null, primary key
#  expires_in       :integer
#  ip_address       :inet
#  refresh_token_bidx       :string
#  refresh_token_ciphertext :text
#  revoked_at               :datetime
#  scopes                   :string
#  token_bidx               :string
#  token_ciphertext         :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  application_id   :bigint
#  user_id          :bigint           not null
#
# Indexes
#
#  index_api_tokens_on_application_id       (application_id)
#  index_api_tokens_on_ip_address           (ip_address)
#  index_api_tokens_on_refresh_token_bidx   (refresh_token_bidx) UNIQUE
#  index_api_tokens_on_token_bidx           (token_bidx) UNIQUE
#  index_api_tokens_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ApiToken < ApplicationRecord
  include ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessToken

  self.table_name = "api_tokens"

  alias_attribute :resource_owner_id, :user_id

  PREFIX = "hcb_"
  SIZE = 32

  scope :not_expired, -> { where(expires_in: nil).or(where("(api_tokens.created_at + make_interval(secs => expires_in)) >= ?", Time.now)) }
  scope :not_revoked, -> { where(revoked_at: nil).or(where(revoked_at: Time.now..)) }

  scope :accessible, -> { not_expired.and(not_revoked) }

  has_encrypted :token
  blind_index :token

  has_encrypted :refresh_token
  blind_index :refresh_token

  belongs_to :user

  def self.generate(options = {})
    token_size = options.delete(:size) || SIZE
    PREFIX + SecureRandom.urlsafe_base64(token_size)
  end

  def abbreviated = "#{token[..7]}...#{token[-3..]}"

  def geocode_result
    return nil unless ip_address.present?
    return @geocode_result if defined?(@geocode_result)

    @geocode_result = Geocoder.search(ip_address.to_s)&.first
  end

  def latitude
    geocode_result&.latitude
  end

  def longitude
    geocode_result&.longitude
  end

end
