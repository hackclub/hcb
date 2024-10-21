class CreateHcbCodeTagSuggestion < ActiveRecord::Migration[7.1]
  def change
    create_table :hcb_code_tag_suggestions do |t|
      t.belongs_to :hcb_code, null: false, foreign_key: true
      t.belongs_to :tag, null: false, foreign_key: true
      t.string :aasm_state
      t.timestamps
    end
  end
end
