# frozen_string_literal: true

# == Schema Information
#
# Table name: ledgers
#
#  id            :bigint           not null, primary key
#  primary       :boolean          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  card_grant_id :bigint
#  event_id      :bigint
#
# Indexes
#
#  index_ledgers_on_card_grant_id   (card_grant_id)
#  index_ledgers_on_event_id        (event_id)
#  index_ledgers_on_id_and_primary  (id,primary) UNIQUE
#  index_ledgers_unique_card_grant  (card_grant_id) UNIQUE WHERE (card_grant_id IS NOT NULL)
#  index_ledgers_unique_event       (event_id) UNIQUE WHERE (event_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (card_grant_id => card_grants.id)
#  fk_rails_...  (event_id => events.id)
#
class Ledger < ApplicationRecord
  self.table_name = "ledgers"

  include Hashid::Rails
  hashid_config salt: Credentials.fetch(:HASHID_SALT)
  has_paper_trail

  # Possible owners for a primary ledger
  belongs_to :event, optional: true
  belongs_to :card_grant, optional: true
  validate :validate_owner_based_on_primary

  has_many :mappings, class_name: "Ledger::Mapping"
  has_many :items, through: :mappings, source: :ledger_item, class_name: "Ledger::Item"

  def can_front_balance?
    event&.can_front_balance? || false
  end

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
