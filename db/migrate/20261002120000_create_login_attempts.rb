# frozen_string_literal: true

class CreateLoginAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :login_attempts do |t|
      t.references :login, null: false, foreign_key: true
      t.string :factor, null: false
      t.string :status, null: false, default: "pending"
      t.inet :ip_address
      t.text :user_agent

      t.timestamps
    end

    add_index :login_attempts, :created_at
  end

end
