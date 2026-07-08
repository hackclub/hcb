# frozen_string_literal: true

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
