# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_pending_stripe_service_fee_transactions
#
#  id                    :bigint           not null, primary key
#  amount_cents          :integer
#  date_posted           :date
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  stripe_service_fee_id :bigint           not null
#
# Indexes
#
#  index_rp_stripe_service_fee_txs_on_stripe_service_fee_id  (stripe_service_fee_id)
#
# Foreign Keys
#
#  fk_rails_...  (stripe_service_fee_id => stripe_service_fees.id)
#
class RawPendingStripeServiceFeeTransaction < ApplicationRecord
  monetize :amount_cents

  has_one :canonical_pending_transaction
  belongs_to :stripe_service_fee

  def date
    date_posted
  end

  def memo
    stripe_service_fee.stripe_description
  end

end
