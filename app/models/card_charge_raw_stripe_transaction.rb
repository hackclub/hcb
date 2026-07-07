# frozen_string_literal: true

# == Schema Information
#
# Table name: card_charge_raw_stripe_transactions
#
#  id                        :bigint           not null, primary key
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  card_charge_id            :bigint           not null
#  raw_stripe_transaction_id :bigint           not null
#
# Indexes
#
#  index_card_charge_raw_stripe_transactions_on_card_charge_id  (card_charge_id)
#  index_card_charge_rsts_on_raw_stripe_transaction_id          (raw_stripe_transaction_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (card_charge_id => card_charges.id) ON DELETE => cascade
#  fk_rails_...  (raw_stripe_transaction_id => raw_stripe_transactions.id) ON DELETE => cascade
#
class CardChargeRawStripeTransaction < ApplicationRecord
  belongs_to :card_charge
  belongs_to :raw_stripe_transaction

end
