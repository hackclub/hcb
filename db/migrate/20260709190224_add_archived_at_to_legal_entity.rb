class AddArchivedAtToLegalEntity < ActiveRecord::Migration[8.0]
  def change
    add_column :legal_entities, :archived_at, :datetime
  end
end
