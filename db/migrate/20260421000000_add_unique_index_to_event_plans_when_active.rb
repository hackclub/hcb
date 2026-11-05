class AddUniqueIndexToEventPlansWhenActive < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :event_plans, :event_id,
              unique: true,
              where: "aasm_state = 'active'",
              name: "index_event_plans_on_event_id_when_active",
              algorithm: :concurrently
  end
end
