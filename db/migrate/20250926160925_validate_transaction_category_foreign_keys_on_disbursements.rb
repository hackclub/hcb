class ValidateTransactionCategoryForeignKeysOnDisbursements < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key(
      :disbursements,
      column: :source_transaction_category_id,
    )

    validate_foreign_key(
      :disbursements,
      column: :destination_transaction_category_id,
    )
  end
end
