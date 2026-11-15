# frozen_string_literal: true

class AddTransferTypeToDisbursements < ActiveRecord::Migration[8.1]
  def change
    add_column :disbursements, :transfer_type, :string
  end

end
