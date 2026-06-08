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
      errors.add(:base, "#{"Merchant".pluralize(conflicts.size)} #{conflicts.join(", ")} cannot be both allowed and blocked") if conflicts.any?
    end

    validate do
      conflicts = allowed_categories & disallowed_categories
      errors.add(:base, "#{"Category".pluralize(conflicts.size)} #{conflicts.join(", ")} cannot be both allowed and blocked") if conflicts.any?
    end
  end
end
