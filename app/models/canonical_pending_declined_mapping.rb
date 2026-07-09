# frozen_string_literal: true

# == Schema Information
#
# Table name: canonical_pending_declined_mappings
#
#  id                               :bigint           not null, primary key
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  canonical_pending_transaction_id :bigint           not null
#
# Indexes
#
#  index_canonical_pending_declined_mappings_on_cpt_id  (canonical_pending_transaction_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (canonical_pending_transaction_id => canonical_pending_transactions.id)
#
class CanonicalPendingDeclinedMapping < ApplicationRecord
  belongs_to :canonical_pending_transaction

  after_create_commit do
    # Sometimes a reimbursement report will be reversed after the money has
    # moved from the organization to HCB Reimbursement Clearinghouse. Upon reversal,
    # HCB creates a CanonicalPendingDeclinedMapping for the CanonicalPendingTransaction.
    # So, we need to destroy the settle mapping if it's going to be declined.
    if canonical_pending_transaction.canonical_pending_settled_mappings.any?
      canonical_pending_transaction.canonical_pending_settled_mappings.destroy_all
      Rails.error.unexpected "CPT ##{canonical_pending_transaction.id} had both a decline and a settle mapping. The settle mapping was destroyed."
    end
  end

  after_commit if: -> { canonical_pending_transaction.ledger_item.present? } do
    canonical_pending_transaction.ledger_item.map!
    canonical_pending_transaction.ledger_item.refresh!
  end

end
