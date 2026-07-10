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

  validate :not_already_settled, on: :create

  after_commit if: -> { canonical_pending_transaction.ledger_item.present? } do
    canonical_pending_transaction.ledger_item.map!
    canonical_pending_transaction.ledger_item.refresh!
  end

  private

  def not_already_settled
    return unless canonical_pending_transaction&.canonical_pending_settled_mappings&.exists?

    errors.add(:canonical_pending_transaction, "already has a settled mapping")
    Rails.error.unexpected "Attempted to create a decline mapping for CPT ##{canonical_pending_transaction.id}, but it already has a settle mapping."
  end

end
