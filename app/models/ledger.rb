# frozen_string_literal: true

class Ledger < ApplicationRecord
  def self.table_name_prefix = "ledger_"

  # Possible owners for a primary ledger
  belongs_to :event, optional: true
  belongs_to :card_grant, optional: true

  validate :validate_owner_based_on_primary

  private

  def validate_owner_based_on_primary
    if primary?
      # Primary ledger must have exactly one owner
      if event_id.nil? && card_grant_id.nil?
        errors.add(:base, "Primary ledger must have an owner (event or card grant)")
      end

      if event_id.present? && card_grant_id.present?
        errors.add(:base, "Primary ledger cannot have more than one owner")
      end
    else
      # Non-primary ledger must not have any owners
      if event_id.present? || card_grant_id.present?
        errors.add(:base, "Non-primary ledger cannot have an owner")
      end
    end
  end

end
