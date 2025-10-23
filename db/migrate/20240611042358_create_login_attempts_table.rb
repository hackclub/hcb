class CreateLoginAttemptsTable < ActiveRecord::Migration[7.1]
  def change
    create_table :logins do |t|
      t.belongs_to :user, null: false
      t.belongs_to :user_session
      t.string :aasm_state
      t.jsonb :authentication_factors
      t.timestamps
    end
  end
end
