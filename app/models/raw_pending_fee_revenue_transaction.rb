# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_pending_fee_revenue_transactions
#
#  id             :bigint           not null, primary key
#  amount_cents   :integer
#  date_posted    :date
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  fee_revenue_id :bigint           not null
#
# Indexes
#
#  index_raw_pending_fee_revenue_transactions_on_fee_revenue_id  (fee_revenue_id)
#
# Foreign Keys
#
#  fk_rails_...  (fee_revenue_id => fee_revenues.id)
#
class RawPendingFeeRevenueTransaction < ApplicationRecord
  monetize :amount_cents

  has_one :canonical_pending_transaction
  belongs_to :fee_revenue

  def date
    date_posted
  end

  def memo
    "Fee revenue for #{fee_revenue.start.strftime("%-m/%-d")} to #{fee_revenue.end.strftime("%-m/%-d")}"
  end

end
