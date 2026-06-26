# frozen_string_literal: true

class AddCheckAndAchTransferReferencesToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_reference :transact_so_ns, :check, foreign_key: true
    add_reference :transact_so_ns, :ach_transfer, foreign_key: true
  end

end
