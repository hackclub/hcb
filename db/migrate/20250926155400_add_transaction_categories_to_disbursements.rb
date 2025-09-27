class AddTransactionCategoriesToDisbursements < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference(
      :disbursements,
      :source_transaction_category,
      index: { algorithm: :concurrently },
      null: true
    )

    add_reference(
      :disbursements,
      :destination_transaction_category,
      index: { algorithm: :concurrently },
      null: true
    )
  end
end
