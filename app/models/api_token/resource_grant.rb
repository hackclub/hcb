# frozen_string_literal: true

# == Schema Information
#
# Table name: api_token_resource_grants
#
#  id              :bigint           not null, primary key
#  access_level    :string           not null
#  resource_type   :string           not null
#  scope_root_type :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  api_token_id    :bigint           not null
#  scope_root_id   :bigint
#
# Indexes
#
#  idx_on_scope_root_type_scope_root_id_c858ad0f72              (scope_root_type,scope_root_id)
#  index_api_token_resource_grants_on_api_token_id              (api_token_id)
#  index_api_token_resource_grants_on_token_and_type_and_level  (api_token_id,resource_type,access_level)
#
# Foreign Keys
#
#  fk_rails_...  (api_token_id => api_tokens.id)
#
class ApiToken::ResourceGrant < ApplicationRecord
  self.table_name = "api_token_resource_grants"

  include ResourceGrantable

  belongs_to :api_token

end
