# frozen_string_literal: true

# == Schema Information
#
# Table name: canonical_pending_event_mappings
#
#  id                               :bigint           not null, primary key
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  canonical_pending_transaction_id :bigint           not null
#  event_id                         :bigint           not null
#  subledger_id                     :bigint
#
# Indexes
#
#  index_canonical_pending_event_map_on_canonical_pending_tx_id  (canonical_pending_transaction_id)
#  index_canonical_pending_event_mappings_on_event_id            (event_id)
#  index_canonical_pending_event_mappings_on_subledger_id        (subledger_id)
#
# Foreign Keys
#
#  fk_rails_...  (canonical_pending_transaction_id => canonical_pending_transactions.id)
#  fk_rails_...  (event_id => events.id)
#
class CanonicalPendingEventMapping < ApplicationRecord
  broadcasts_refreshes_to ->(mapping) { [mapping.event, :transactions] }

  belongs_to :canonical_pending_transaction
  belongs_to :event
  belongs_to :subledger, optional: true

  scope :on_main_ledger, -> { where(subledger_id: nil) }

end
