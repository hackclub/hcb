# frozen_string_literal: true

stripe_transaction = hcb_code.ct&.raw_stripe_transaction&.stripe_transaction
stripe_authorization = hcb_code.pt&.raw_pending_stripe_transaction&.stripe_transaction

json.merchant do
  merchant_data = (stripe_transaction || stripe_authorization)["merchant_data"]

  json.name merchant_data["name"]
  json.smart_name humanized_merchant_name(merchant_data) rescue nil
  json.country merchant_data["country"]
  json.network_id merchant_data["network_id"]
end

json.charge_method stripe_authorization&.dig("authorization_method")
json.spent_at Time.at((stripe_authorization || stripe_transaction)["created"], in: "UTC")
json.wallet stripe_authorization&.dig("wallet")

json.card do
  expand :user do
    json.partial! "api/v4/stripe_cards/stripe_card", stripe_card: hcb_code.stripe_card
  end
end
