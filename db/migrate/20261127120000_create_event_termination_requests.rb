# frozen_string_literal: true

class CreateEventTerminationRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :event_termination_requests do |t|
      t.references :event, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.text :reason, null: false
      t.datetime :withdrawn_at
      t.datetime :closed_at
      t.references :closed_by, foreign_key: { to_table: :users }

      t.timestamps

      # An organization may have at most one pending request at a time.
      t.index :event_id, unique: true, where: "withdrawn_at IS NULL AND closed_at IS NULL", name: "index_event_termination_requests_on_pending_event_id"
    end
  end

end
