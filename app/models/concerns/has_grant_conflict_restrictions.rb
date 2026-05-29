# frozen_string_literal: true

module HasGrantConflictRestrictions
  extend ActiveSupport::Concern

  included do
    validate :no_conflicting_merchant_lists
    validate :no_conflicting_category_lists
  end

  private

  def no_conflicting_merchant_lists
    conflicts = merchant_lock & banned_merchants
    errors.add(:base, "Merchant(s) #{conflicts.join(', ')} cannot be both allowed and blocked") if conflicts.any?
  end

  def no_conflicting_category_lists
    conflicts = category_lock & banned_categories
    category_label = conflicts.one? ? "Category" : "Categories"
    errors.add(:base, "#{category_label} #{conflicts.join(', ')} cannot be both allowed and blocked") if conflicts.any?
  end
end
