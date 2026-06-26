# frozen_string_literal: true

class RemoveInvalidFieldsFromTransactions < ActiveRecord::Migration[5.2]
  def change
    remove_column :transact_so_ns, :payment_meta_payee_name, :text
  end

end
