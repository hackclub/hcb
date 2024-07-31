# frozen_string_literal: true

module HasStripeDashboardUrl
  extend ActiveSupport::Concern
  included do
    def self.has_stripe_dashboard_url(resource, id_field)
      self.define_method(:stripe_dashboard_url) do
        id = self.try(id_field)
        return if id.nil?

        url = "https://dashboard.stripe.com"
        url += "/test" if StripeService.mode == :test
        url += "/#{resource}/#{id}"

        url
      end
    end
  end

end
