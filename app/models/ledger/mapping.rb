# frozen_string_literal: true

# == Schema Information
#
# Table name: ledger_mappings
#
#  id                :bigint           not null, primary key
#  on_primary_ledger :boolean          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  ledger_id         :bigint           not null
#  ledger_item_id    :bigint           not null
#  mapped_by_id      :bigint
#
# Indexes
#
#  index_ledger_mappings_on_ledger_and_item      (ledger_id,ledger_item_id) UNIQUE
#  index_ledger_mappings_on_ledger_id            (ledger_id)
#  index_ledger_mappings_on_ledger_item_id       (ledger_item_id)
#  index_ledger_mappings_on_mapped_by_id         (mapped_by_id)
#  index_ledger_mappings_unique_item_on_primary  (ledger_item_id) UNIQUE WHERE (on_primary_ledger = true)
#
# Foreign Keys
#
#  fk_ledger_mappings_primary_match  ([ledger_id, on_primary_ledger] => ledgers[id, primary])
#  fk_rails_...                      (ledger_id => ledgers.id)
#  fk_rails_...                      (ledger_item_id => ledger_items.id)
#  fk_rails_...                      (mapped_by_id => users.id)
#
class Ledger
  class Mapping < ApplicationRecord
    self.table_name = "ledger_mappings"

    has_paper_trail

    belongs_to :ledger, class_name: "::Ledger"
    belongs_to :ledger_item, class_name: "Ledger::Item"

    belongs_to :mapped_by, class_name: "User", optional: true

    validates :ledger_item_id, uniqueness: { scope: :ledger_id, message: "is already mapped to this ledger" }
    validates :ledger_item_id, uniqueness: { conditions: -> { where(on_primary_ledger: true) }, message: "is already mapped on a primary ledger" }, if: :on_primary_ledger?
    validate :on_primary_ledger_matches_ledger_primary

    private

    def on_primary_ledger_matches_ledger_primary
      # IMPORTANT: The composite foreign key fk_ledger_mappings_primary_match
      # enforces that on_primary_ledger matches ledger.primary at the database
      # level. It works by creating a FK on (ledger_id, on_primary_ledger) that
      # references (id, primary) in the ledgers table. This ensures the
      # combination of values must exist in ledgers, which means on_primary_ledger
      # MUST equal ledger.primary.
      if on_primary_ledger? != ledger.primary?
        errors.add(:on_primary_ledger, "must match ledger's primary status")
      end
    end

  end


end
