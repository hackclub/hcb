# frozen_string_literal: true

module HasAddressCountry
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_address_country

    # We store countries as ISO 3166-1 alpha-2 codes (e.g. "US", "CA", "GB"),
    # matching the rest of our address fields and what we forward to Stripe.
    validates :address_country, inclusion: {
      in: ISO3166::Country.codes,
      message: "is not a valid country"
    }, allow_blank: true

    private

    def normalize_address_country
      self.address_country = address_country&.strip&.upcase.presence
    end
  end
end
