# frozen_string_literal: true

class AddWiseRecipientIdToReimbursementWiseTransferDrafts < ActiveRecord::Migration[7.0]
  def change
    add_column :reimbursement_wise_transfer_drafts, :wise_recipient_id, :text
  end
end
