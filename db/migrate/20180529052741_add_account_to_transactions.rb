# frozen_string_literal: true

class AddAccountToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_reference :transact_so_ns, :bank_account, foreign_key: true
  end

end
