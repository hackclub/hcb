class AddEventGroups < ActiveRecord::Migration[7.2]
  def change
    create_table(:event_groups) do |t|
      t.citext(:name, null: false)
      t.references(:user, null: false, foreign_key: true)
      t.timestamps

      t.index(:name, unique: true)
    end

    create_table(:event_group_memberships) do |t|
      t.references(:event_group, null: false, foreign_key: true)
      t.references(:event, null: false, foreign_key: true, index: false)
      t.timestamps

      t.index([:event_id, :event_group_id], unique: true)
    end
  end
end
