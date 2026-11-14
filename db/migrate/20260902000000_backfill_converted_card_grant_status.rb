# frozen_string_literal: true

# Grants accepted as reimbursements were previously stored as `canceled` with a
# reimbursement report attached, and "converted" was inferred from that pair.
# They now have a dedicated `converted_to_reimbursement` status, so existing rows
# need to be moved onto it.
class BackfillConvertedCardGrantStatus < ActiveRecord::Migration[8.1]
  def up
    CardGrant.where(status: :canceled)
             .where(id: Reimbursement::Report.where.not(card_grant_id: nil).select(:card_grant_id))
             .update_all(status: CardGrant.statuses[:converted_to_reimbursement])
  end

  def down
    CardGrant.where(status: :converted_to_reimbursement)
             .update_all(status: CardGrant.statuses[:canceled])
  end

end
