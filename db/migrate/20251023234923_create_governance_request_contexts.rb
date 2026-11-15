class CreateGovernanceRequestContexts < ActiveRecord::Migration[7.2]
  def change
    create_table :governance_request_contexts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :impersonator, null: true, foreign_key: { to_table: :users }
      t.references :authentication_session, polymorphic: true, null: false

      t.inet :ip_address, null: false
      t.string :user_agent, null: false
      t.string :request_id, null: false

      t.string :http_method, null: false
      t.string :path, null: false
      t.string :controller_name, null: false
      t.string :action_name, null: false

      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :governance_request_contexts, :request_id, unique: true
    add_index :governance_request_contexts, :ip_address

  end
end
