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

  # Merchant name prefixes blocked HCB-wide. Matched case-insensitively against
  # the beginning of the merchant name, so "FAWRA*" also blocks
  # "FAWRA*A1B2C3". Like FORBIDDEN_MERCHANT_NETWORK_IDS, a merchant matching
  # one of these can never be allowlisted.
  FORBIDDEN_MERCHANT_NAME_PREFIXES =
    Set.new(
      [
        "FAWRA*" # Fawra Pay, primarily used for fraud on HQ satellites. Requested by the HQ Events team.
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

  def self.forbidden_merchant_name?(merchant_name)
    normalized = merchant_name.to_s.strip.downcase
    return false if normalized.blank?

    FORBIDDEN_MERCHANT_NAME_PREFIXES.any? { |prefix| normalized.start_with?(prefix.downcase) }
  end
end
