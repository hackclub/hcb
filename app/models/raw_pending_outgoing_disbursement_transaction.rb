# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_pending_outgoing_disbursement_transactions
#
#  id              :bigint           not null, primary key
#  amount_cents    :integer
#  date_posted     :date
#  state           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  disbursement_id :bigint
#
# Indexes
#
#  index_rpodts_on_disbursement_id  (disbursement_id)
#
# Foreign Keys
#
#  fk_rails_...  (disbursement_id => disbursements.id)
#
class RawPendingOutgoingDisbursementTransaction < ApplicationRecord
  monetize :amount_cents

  has_one :canonical_pending_transaction
  belongs_to :disbursement

  def date
    disbursement.in_transit_at || disbursement.created_at
  end

  def memo
    "Outgoing transfer"
  end

  def likely_event_id
    @likely_event_id ||= disbursement.source_event.id
  end

end
