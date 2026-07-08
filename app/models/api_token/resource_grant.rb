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
# Narrows (or, for the admin capability path - see ApiAdminContext - grants)
# an ApiToken's access to a resource type. Two shapes:
#   - no scope_root: the whole resource type, no further narrowing. For a
#     general resource scope (e.g. "comments:read") this is a no-op, since
#     the scope string alone already grants the whole type. For an admin
#     resource-type scope this IS the capability grant - it replaces what
#     used to be the "admin.<resource>:<level>" scope string.
#   - scope_root_type + scope_root_id set: every record whose #api_scope_roots
#     includes this root is covered, e.g. all comments under a given Event.
class ApiToken::ResourceGrant < ApplicationRecord
  self.table_name = "api_token_resource_grants"

  include ResourceGrantable

  belongs_to :api_token

end
