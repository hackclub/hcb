class CreateTasks < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def change
    create_table :tasks do |t|
      t.string :type, null: false
      t.boolean :complete, default: false
      t.datetime :completed_at
      t.timestamps
    end
    add_reference :tasks, :assignee, polymorphic: true, index: { algorithm: :concurrently }, null: false
    add_reference :tasks, :taskable, polymorphic: true, index: { algorithm: :concurrently }, null: false
  end
end
