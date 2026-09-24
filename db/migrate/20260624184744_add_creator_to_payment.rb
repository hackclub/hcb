class AddCreatorToPayment < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :payments, :creator, null: false, index: {algorithm: :concurrently}
  end
end
