# frozen_string_literal: true

class AddRepaymentAllocationToTransactionSplits < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :transaction_splits, :repayment_allocation, index: { algorithm: :concurrently }
  end

end
