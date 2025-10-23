class CreateEventPlan < ActiveRecord::Migration[7.1]
  def change
    create_table :event_plans do |t|
      t.string :plan_type
      t.string :aasm_state
      t.belongs_to :event, null: false, foreign_key: true
      t.timestamps
    end
  end
end
