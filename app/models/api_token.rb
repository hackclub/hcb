# frozen_string_literal: true

# == Schema Information
#
# Table name: api_tokens
#
#  id               :bigint           not null, primary key
#  expires_in       :integer
#  refresh_token    :string
#  revoked_at       :datetime
#  scopes           :string
#  token_bidx       :string
#  token_ciphertext :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  application_id   :bigint
#  user_id          :bigint           not null
#
# Indexes
#
#  index_api_tokens_on_application_id  (application_id)
#  index_api_tokens_on_token_bidx      (token_bidx) UNIQUE
#  index_api_tokens_on_user_id         (user_id)
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

  has_encrypted :token
  blind_index :token

  belongs_to :user

  def self.generate(options = {})
    token_size = options.delete(:size) || SIZE
    PREFIX + SecureRandom.urlsafe_base64(token_size)
  end

end
