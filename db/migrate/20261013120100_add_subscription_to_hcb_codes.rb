# frozen_string_literal: true

class AddSubscriptionToHcbCodes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :hcb_codes, :subscription, index: { algorithm: :concurrently }
  end

end
