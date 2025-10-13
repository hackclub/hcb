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
        "non_fi_money_orders"
      ]
    ).freeze
end
