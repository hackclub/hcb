# frozen_string_literal: true

class AddEventToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_reference :transact_so_ns, :event, foreign_key: true
  end

end
