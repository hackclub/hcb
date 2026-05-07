# frozen_string_literal: true

class CreateAiQueries < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_queries do |t|
      t.text :prompt, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :attempts, null: false, default: []
      t.jsonb :conversation_history, null: false, default: []
      t.string :generated_name
      t.bigint :creator_id
      t.bigint :blazer_query_id

      t.timestamps
    end

    add_index :ai_queries, :creator_id
    add_index :ai_queries, :blazer_query_id
    add_index :ai_queries, :status
  end
end
