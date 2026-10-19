# frozen_string_literal: true

class CreateCardGrantTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :card_grant_templates do |t|
      t.references :event, null: false, foreign_key: true, index: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.integer :amount_cents
      t.integer :expiration_days
      t.string :purpose
      t.text :instructions
      t.string :invite_message
      t.boolean :one_time_use, null: false, default: false
      t.boolean :pre_authorization_required, null: false, default: false
      t.string :merchant_lock
      t.string :category_lock
      t.string :keyword_lock
      t.string :banned_merchants
      t.string :banned_categories

      t.timestamps
    end

    add_index :card_grant_templates, "event_id, LOWER(name)", unique: true, name: "index_card_grant_templates_on_event_id_and_lower_name"
  end

end
