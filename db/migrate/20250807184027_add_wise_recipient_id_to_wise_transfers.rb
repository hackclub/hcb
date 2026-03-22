# frozen_string_literal: true

class AddWiseRecipientIdToWiseTransfers < ActiveRecord::Migration[7.2]
  def change
    add_column(:wise_transfers, :wise_recipient_id, :text)
  end
end
