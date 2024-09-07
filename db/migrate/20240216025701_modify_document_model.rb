class ModifyDocumentModel < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_column :documents, :archived_at, :datetime
      add_reference :documents, :archived_by,
                      null: true,
                      foreign_key: { to_table: :users },
                      index: { algorithm: :concurrently }
    end
  end
end
