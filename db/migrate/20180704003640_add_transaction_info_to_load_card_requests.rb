# frozen_string_literal: true

class AddTransactionInfoToLoadCardRequests < ActiveRecord::Migration[5.2]
  def change
    add_column :load_card_requests, :emburse_transaction_id, :string
    add_reference :load_card_requests, :transact_son, foreign_key: true
  end

end
