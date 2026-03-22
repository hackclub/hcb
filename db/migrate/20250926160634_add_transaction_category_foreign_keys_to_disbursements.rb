class AddTransactionCategoryForeignKeysToDisbursements < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key(
      :disbursements,
      :transaction_categories,
      column: :source_transaction_category_id,
      validate: false
    )

    add_foreign_key(
      :disbursements,
      :transaction_categories,
      column: :destination_transaction_category_id,
      validate: false
    )
  end
end
