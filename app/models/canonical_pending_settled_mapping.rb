# frozen_string_literal: true

# == Schema Information
#
# Table name: canonical_pending_settled_mappings
#
#  id                               :bigint           not null, primary key
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  canonical_pending_transaction_id :bigint           not null
#  canonical_transaction_id         :bigint           not null
#
# Indexes
#
#  index_canonical_pending_settled_map_on_canonical_pending_tx_id  (canonical_pending_transaction_id)
#  index_canonical_pending_settled_mappings_on_canonical_tx_id     (canonical_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (canonical_pending_transaction_id => canonical_pending_transactions.id)
#  fk_rails_...  (canonical_transaction_id => canonical_transactions.id)
#
class CanonicalPendingSettledMapping < ApplicationRecord
  belongs_to :canonical_pending_transaction
  belongs_to :canonical_transaction

  after_create_commit do
    # Sometimes a Stripe merchant will capture after an authorization has been
    # reversed. Upon reversal, HCB creates a CanonicalPendingDeclinedMapping
    # for the CanonicalPendingTransaction. So, when a captures happens
    # afterwards, we need to destroy the decline mapping if it's going to be
    # settled to a CanonicalTransaction.
    #
    # Raised from https://github.com/hackclub/hcb/issues/7419
    if canonical_pending_transaction.canonical_pending_declined_mapping
      canonical_pending_transaction.canonical_pending_declined_mapping.destroy!
      Airbrake.notify("CPT ##{canonical_pending_transaction.id} had both a decline and a settle mapping. The decline mapping was destroyed.")
    end
  end

end
