# frozen_string_literal: true

class RemoveEventsFromTransactions < ActiveRecord::Migration[5.2]
  def change
    remove_reference :transact_so_ns, :event, foreign_key: true
  end

end
