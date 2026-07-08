# frozen_string_literal: true

# == Schema Information
#
# Table name: api_tokens
#
#  id                       :bigint           not null, primary key
#  expires_in               :integer
#  ip_address               :inet
#  refresh_token_bidx       :text
#  refresh_token_ciphertext :text
#  revoked_at               :datetime
#  scopes                   :string
#  token_bidx               :string
#  token_ciphertext         :text
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  application_id           :bigint
#  user_id                  :bigint           not null
#
# Indexes
#
#  index_api_tokens_on_application_id      (application_id)
#  index_api_tokens_on_ip_address          (ip_address)
#  index_api_tokens_on_refresh_token_bidx  (refresh_token_bidx) UNIQUE
#  index_api_tokens_on_token_bidx          (token_bidx) UNIQUE
#  index_api_tokens_on_user_id             (user_id)
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
  has_encrypted :refresh_token
  blind_index :token
  blind_index :refresh_token

  self.ignored_columns += ["refresh_token"]

  belongs_to :user
  has_many :resource_grants, as: :owner, dependent: :destroy

  def self.generate(options = {})
    token_size = options.delete(:size) || SIZE
    PREFIX + SecureRandom.urlsafe_base64(token_size)
  end

  def resource_grants_for(access_level, resource_type)
    resource_grants.where(access_level: access_level.to_s, resource_type: resource_type.to_s)
  end

  def has_grants_for?(access_level, resource_type)
    resource_grants_for(access_level, resource_type).exists?
  end

  def permits_object?(access_level, resource_type, record)
    grants = resource_grants_for(access_level, resource_type)
    grants.empty? || grants.any? { |grant| grant.covers?(record) }
  end

  # Called after Doorkeeper mints a token, so grants configured on the OAuth
  # application carry over to every token it issues.
  def copy_resource_grants_from_application!
    application&.resource_grants&.find_each do |template|
      resource_grants.create!(template.slice(:resource_type, :access_level, :scope_root_type, :scope_root_id))
    end
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
