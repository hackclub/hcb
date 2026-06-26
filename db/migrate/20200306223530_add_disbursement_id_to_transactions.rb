# frozen_string_literal: true

class AddDisbursementIdToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_reference :transact_so_ns, :disbursement, foreign_key: true
  end

end
