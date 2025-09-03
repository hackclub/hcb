# frozen_string_literal: true

# == Schema Information
#
# Table name: stripe_service_fees
#
#  id                            :bigint           not null, primary key
#  amount_cents                  :integer          not null
#  stripe_description            :string           not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  stripe_balance_transaction_id :string           not null
#  stripe_topup_id               :bigint
#
# Indexes
#
#  index_stripe_service_fees_on_stripe_balance_transaction_id  (stripe_balance_transaction_id) UNIQUE
#  index_stripe_service_fees_on_stripe_topup_id                (stripe_topup_id)
#
class StripeServiceFee < ApplicationRecord
  belongs_to :stripe_topup, optional: true
  after_create_commit do
    topup = StripeTopup.create(
      amount_cents:,
      statement_descriptor: "HCB-#{local_hcb_code.short_code}",
      description: "Paying for: #{stripe_description}",
      metadata: {
        hcb_stripe_service_fee_id: id,
        stripe_balance_transaction_id:
      }
    )
    update!(stripe_topup_id: topup.id)
  end

  def hcb_code
    [
      ::TransactionGroupingEngine::Calculate::HcbCode::HCB_CODE,
      ::TransactionGroupingEngine::Calculate::HcbCode::STRIPE_SERVICE_FEE_CODE,
      id
    ].join(::TransactionGroupingEngine::Calculate::HcbCode::SEPARATOR)
  end

  def local_hcb_code
    HcbCode.find_or_create_by(hcb_code:)
  end

end
