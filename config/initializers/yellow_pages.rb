# frozen_string_literal: true

# when we added icons to the homepage, this became pretty costly.

YellowPages.missing_merchant_reporter = ->(network_id) do
  StatsD.event("MerchantNotFound", network_id)
end
