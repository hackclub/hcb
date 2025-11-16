class AddEventTagsIndexByName < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index(:event_tags, [:name, :purpose], unique: true, algorithm: :concurrently)
  end
end
