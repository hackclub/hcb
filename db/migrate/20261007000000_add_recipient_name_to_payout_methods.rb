# frozen_string_literal: true

class AddRecipientNameToPayoutMethods < ActiveRecord::Migration[8.1]
  def change
    add_column :user_payout_method_checks, :recipient_name, :string
    add_column :user_payout_method_ach_transfers, :recipient_name, :string
  end
end
