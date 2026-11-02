# frozen_string_literal: true

class ScopePayeesLegalEntityUniqueIndexToNotArchived < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :payees, [:legal_entity_id, :event_id],
              unique: true,
              where: "archived_at IS NULL",
              name: "index_payees_on_legal_entity_id_and_event_id_not_archived",
              algorithm: :concurrently
    remove_index :payees, name: "index_payees_on_legal_entity_id_and_event_id", algorithm: :concurrently
  end

  def down
    add_index :payees, [:legal_entity_id, :event_id],
              unique: true,
              name: "index_payees_on_legal_entity_id_and_event_id",
              algorithm: :concurrently
    remove_index :payees, name: "index_payees_on_legal_entity_id_and_event_id_not_archived", algorithm: :concurrently
  end

end
