# frozen_string_literal: true

class DropRawPendingFeeReimbursementTransactions < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      drop_table :raw_pending_fee_reimbursement_transactions do |t|
        t.integer :amount_cents
        t.date :date_posted
        t.references :fee_reimbursement, null: false, foreign_key: true, index: { name: "index_rp_fee_reimbursement_txs_on_fee_reimbursement_id" }

        t.timestamps
      end
    end
  end

end
