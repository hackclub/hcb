# frozen_string_literal: true

class CreateCommentHcbCodes < ActiveRecord::Migration[7.2]
  def change
    create_table :comment_hcb_codes do |t|
      t.references :comment, null: false, foreign_key: true
      t.references :hcb_code, null: false, foreign_key: true

      t.timestamps
    end

    add_index :comment_hcb_codes, [:comment_id, :hcb_code_id], unique: true
  end
end
