# frozen_string_literal: true

class User
  module PayoutMethod

    UNSUPPORTED_METHODS = {
      User::PayoutMethod::PaypalTransfer => {
        status_badge: "Unavailable",
        reason: "Due to integration issues, transfers via PayPal are currently unavailable."
      },
      User::PayoutMethod::WiseTransfer   => {
        status_badge: "Temporarily Unavailable",
        reason: "Wise Transfers are currently under maintenance."
      }
    }.freeze

    def kind
      "unknown"
    end

    def icon
      "docs"
    end

    def name
      "an unknown method"
    end

    def human_kind
      "unknown"
    end

    def title_kind
      "Unknown"
    end

    def currency
      "USD"
    end

  end

end
