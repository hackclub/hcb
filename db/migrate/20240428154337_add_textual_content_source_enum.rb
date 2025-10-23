class AddTextualContentSourceEnum < ActiveRecord::Migration[7.0]
  def change
    add_column :receipts, :textual_content_source, :integer, default: 0
  end
end
