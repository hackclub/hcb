# frozen_string_literal: true

class ForcePlaidIdUniquenessOnTransactions < ActiveRecord::Migration[5.2]
  def change
    add_index :transact_so_ns, :plaid_id, unique: true
  end

end
