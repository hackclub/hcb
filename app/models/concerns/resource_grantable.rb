# frozen_string_literal: true

# Shared shape for a "grant" of resource access, used by both:
#   - ApiToken::ResourceGrant: a live grant on an issued token.
#   - Doorkeeper::Application::ResourceGrantTemplate: a template copied onto
#     every token minted for an application (see the
#     after_successful_strategy_response hook in config/initializers/doorkeeper.rb).
#
# Two shapes - see ApiToken::ResourceGrant for the full explanation of what
# each means at enforcement time:
#   - scope_root unset: the whole resource type.
#   - scope_root_type + scope_root_id set: everything under that root.
module ResourceGrantable
  extend ActiveSupport::Concern

  ACCESS_LEVELS = %w[read write].freeze
  SCOPE_ROOT_TYPES = %w[User Event].freeze

  included do
    validates :resource_type, presence: true
    validates :access_level, inclusion: { in: ACCESS_LEVELS }
    validates :scope_root_type, inclusion: { in: SCOPE_ROOT_TYPES }, allow_nil: true
    validate :scope_root_type_and_id_are_set_together
  end

  private

  def scope_root_type_and_id_are_set_together
    if scope_root_type.present? ^ scope_root_id.present?
      errors.add(:base, "scope_root_type and scope_root_id must be set together")
    end
  end
end
