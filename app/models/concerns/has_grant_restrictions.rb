# frozen_string_literal: true

module HasGrantRestrictions
  extend ActiveSupport::Concern

  RESTRICTION_ATTRIBUTES = %w[merchant_lock category_lock banned_merchants banned_categories].freeze

  included do
    alias_attribute :allowed_merchants, :merchant_lock
    alias_attribute :allowed_categories, :category_lock
    alias_attribute :disallowed_merchants, :banned_merchants
    alias_attribute :disallowed_categories, :banned_categories

    validate if: :restrictions_changed? do
      conflicts = allowed_merchants & disallowed_merchants
      if conflicts.any?
        label = "Merchant".pluralize(conflicts.size)
        errors.add(:base, "#{label} #{conflicts.join(", ")} cannot be both allowed and blocked")
      end
    end

    validate if: :restrictions_changed? do
      conflicts = allowed_categories & disallowed_categories
      if conflicts.any?
        label = "Category".pluralize(conflicts.size)
        errors.add(:base, "#{label} #{conflicts.join(", ")} cannot be both allowed and blocked")
      end
    end
  end

  private

  # Skip unrelated saves so records that predate a conflicting setting change aren't bricked
  def restrictions_changed?
    changed.intersect?(RESTRICTION_ATTRIBUTES)
  end
end
