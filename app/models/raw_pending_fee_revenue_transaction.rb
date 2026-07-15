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
