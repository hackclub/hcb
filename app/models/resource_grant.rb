# frozen_string_literal: true

# == Schema Information
#
# Table name: resource_grants
#
#  id              :bigint           not null, primary key
#  access_level    :string           not null
#  owner_type      :string           not null
#  resource_type   :string           not null
#  scope_root_type :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  owner_id        :bigint           not null
#  scope_root_id   :bigint
#
# Indexes
#
#  index_resource_grants_on_owner                              (owner_type,owner_id)
#  index_resource_grants_on_owner_and_resource_type            (owner_type,owner_id,resource_type)
#  index_resource_grants_on_scope_root_type_and_scope_root_id  (scope_root_type,scope_root_id)

class ResourceGrant < ApplicationRecord
  ACCESS_LEVELS = %w[read write].freeze
  SCOPE_ROOT_TYPES = %w[User Event].freeze
  OWNER_TYPES = %w[ApiToken Doorkeeper::Application].freeze

  belongs_to :owner, polymorphic: true

  validates :resource_type, presence: true
  validates :access_level, inclusion: { in: ACCESS_LEVELS }
  validates :scope_root_type, inclusion: { in: SCOPE_ROOT_TYPES }, allow_nil: true
  validate :scope_root_type_and_id_are_set_together

  private

  def scope_root_type_and_id_are_set_together
    if scope_root_type.present? ^ scope_root_id.present?
      errors.add(:base, "scope_root_type and scope_root_id must be set together")
    end
  end

end
