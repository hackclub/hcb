# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_pending_fee_revenue_transactions
#
#  id                         :bigint           not null, primary key
#  amount_cents               :integer          not null
#  date_posted                :date             not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  fee_revenue_transaction_id :string           not null
#
# Indexes
#
#  index_raw_pending_fee_revenue_txs_on_fee_revenue_tx_id  (fee_revenue_transaction_id) UNIQUE
#
class RawPendingFeeRevenueTransaction < ApplicationRecord
  monetize :amount_cents
  has_one :canonical_pending_transaction

  def date
    date_posted
  end

  def memo
    "Fee revenue for #{fee_revenue.start.strftime("%-m/%-d")} to #{fee_revenue.end.strftime("%-m/%-d")}"
  end

  def likely_event_id
    EventMappingEngine::EventIds::HACK_CLUB_BANK
  end

  def fee_revenue
    @fee_revenue ||= ::FeeRevenue.find_by(id: fee_revenue_transaction_id)
  end

end
