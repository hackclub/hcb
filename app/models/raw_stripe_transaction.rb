# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_stripe_transactions
#
#  id                      :bigint           not null, primary key
#  amount_cents            :integer
#  date_posted             :date
#  stripe_transaction      :jsonb
#  unique_bank_identifier  :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  stripe_authorization_id :text
#  stripe_transaction_id   :text
#
# Indexes
#
#  index_raw_stripe_transactions_on_card_id_text  ((((stripe_transaction -> 'card'::text) ->> 'id'::text))) USING hash
#
class RawStripeTransaction < ApplicationRecord
  has_many :hashed_transactions
  has_one :canonical_transaction, as: :transaction_source

  include ActiveSupport::NumberHelper

  ZERO_DECIMAL_CURRENCIES = %w[BIF CLP DJF GNF JPY KMF KRW MGA PYG RWF UGX VND VUV XAF XOF XPF].freeze

  def memo
    @memo ||= stripe_transaction.dig("merchant_data", "name")
  end

  def likely_event_id
    @likely_event_id ||= ::StripeCard.find_by!(stripe_id: stripe_card_id).event_id
  end

  def refund?
    stripe_transaction["type"] == "refund"
  end

  def local_amount
    currency = stripe_transaction["merchant_currency"]&.upcase
    amount = stripe_transaction["merchant_amount"].abs

    return nil if currency.nil? || currency == "USD"

    if ZERO_DECIMAL_CURRENCIES.include?(currency)
      "#{number_to_delimited(amount)} #{currency}"
    else
      "#{number_to_currency(BigDecimal((amount || 0).to_s) / 100, unit: "")} #{currency}"
    end
  end

  private

  def stripe_card_id
    stripe_transaction["card"]
  end

end
