class AddCategoryToDocuments < ActiveRecord::Migration[7.2]
  def change
    add_column :documents, :category, :integer, default: 0, null: false
  end
end
