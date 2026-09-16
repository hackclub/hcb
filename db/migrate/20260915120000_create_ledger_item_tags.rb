# frozen_string_literal: true

class CreateLedgerItemTags < ActiveRecord::Migration[7.2]
  def change
    create_table :ledger_items_tags, primary_key: [:ledger_item_id, :tag_id] do |t|
      # Composite PK already indexes (ledger_item_id, tag_id), which covers
      # ledger_item_id lookups, so only tag_id needs its own index.
      t.belongs_to :ledger_item, null: false, foreign_key: true, index: false
      t.belongs_to :tag, null: false, foreign_key: true

      t.timestamps
    end
  end

end
