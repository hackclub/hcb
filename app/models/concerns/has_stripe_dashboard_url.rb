# frozen_string_literal: true

module HasStripeDashboardUrl
  extend ActiveSupport::Concern
  included do
    # Defines a method (named `stripe_dashboard_url` unless `as:` is given)
    # that links to the Stripe dashboard page for the object whose ID is
    # returned by `id_field`.
    def self.has_stripe_dashboard_url(resource, id_field, as: :stripe_dashboard_url)
      self.define_method(as) do
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
