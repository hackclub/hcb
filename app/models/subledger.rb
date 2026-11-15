# frozen_string_literal: true

# == Schema Information
#
# Table name: subledgers
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :bigint           not null
#
# Indexes
#
#  index_subledgers_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Subledger < ApplicationRecord
  belongs_to :event

  has_one :card_grant

  has_many :hcb_codes

  has_many :canonical_event_mappings
  has_many :canonical_transactions, through: :canonical_event_mappings

  has_many :canonical_pending_event_mappings
  has_many :canonical_pending_transactions, through: :canonical_pending_event_mappings

  # The old transaction engine's balance, for comparison against the ledger in
  # Ledger::AssertCorrectLedgerBalancesJob. Use CardGrant#balance_cents instead.
  #
  # It drifts whenever a transaction's event mapping and its settlement land in
  # different jobs. E.g. a grant top-up's canonical transaction is imported and
  # mapped by TransactionEngine::NightlyJob, but its pending transaction is only
  # settled by the next PendingEventMappingEngine::NightlyJob, so it counts twice
  # in between.
  def legacy_balance_cents
    canonical_transactions.sum(:amount_cents) +
      canonical_pending_transactions.outgoing.unsettled.sum(:amount_cents) +
      canonical_pending_transactions.incoming_disbursement.unsettled.fronted.sum(:amount_cents)
  end

end
