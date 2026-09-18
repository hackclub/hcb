# frozen_string_literal: true

module HasGrantRestrictions
  extend ActiveSupport::Concern

  included do
    alias_attribute :allowed_merchants, :merchant_lock
    alias_attribute :allowed_categories, :category_lock
    alias_attribute :disallowed_merchants, :banned_merchants
    alias_attribute :disallowed_categories, :banned_categories

    validate do
      conflicts = allowed_merchants & disallowed_merchants
      if conflicts.any?
        label = "Merchant".pluralize(conflicts.size)
        errors.add(:base, "#{label} #{conflicts.join(", ")} cannot be both allowed and blocked")
      end
    end

    validate do
      conflicts = allowed_categories & disallowed_categories
      if conflicts.any?
        label = "Category".pluralize(conflicts.size)
        errors.add(:base, "#{label} #{conflicts.join(", ")} cannot be both allowed and blocked")
      end
    end
  end
end
