# frozen_string_literal: true

class AddMissingFieldsToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transact_so_ns, :payment_meta_by_order_of, :text
    add_column :transact_so_ns, :payment_meta_payee, :text
    add_column :transact_so_ns, :payment_meta_payer, :text
    add_column :transact_so_ns, :payment_meta_payment_method, :text
    add_column :transact_so_ns, :payment_meta_payment_processor, :text
    add_column :transact_so_ns, :payment_meta_reason, :text
  end

end
