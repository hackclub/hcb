# frozen_string_literal: true

module StripeAuthorizationService
  FORBIDDEN_MERCHANT_CATEGORIES =
    Set.new(
      [
        "betting_casino_gambling",
        # This looks like a typo but matches Stripe's documentation
        # https://docs.stripe.com/issuing/categories
        "government_licensed_online_casions_online_gambling_us_region_only",
        "government_licensed_horse_dog_racing_us_region_only",
        "government_owned_lotteries_non_us_region",
        "government_owned_lotteries_us_region_only",
        "wires_money_orders",
        "non_fi_money_orders",
        "non_fi_stored_value_card_purchase_load"
      ]
    ).freeze

  FORBIDDEN_MERCHANT_NETWORK_IDS =
    Set.new(
      [
        "8203300025" # HEPTA PAY LTD (primary used for fraud; https://hcb.hackclub.com/blazer/queries/1118-hepta-pay-ltd-card-transactions)
      ]
    ).freeze

  # Network IDs that are allowed even when their merchant category is forbidden.
  # This does NOT override FORBIDDEN_MERCHANT_NETWORK_IDS — explicitly blocked
  # network IDs (e.g. fraud) can never be allowlisted.
  ALLOWLISTED_MERCHANT_NETWORK_IDS =
    Set.new(
      [
        "088011245800" # AlipayHK "Add Card" to wallet (non_fi_money_orders)
      ]
    ).freeze
end
