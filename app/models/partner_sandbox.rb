# frozen_string_literal: true

class PartnerSandbox < Partner
  validate :validate_stripe_keys_are_test_mode

  private

  include Partners::Stripe::Constants

  def validate_stripe_keys_are_test_mode

    if self.stripe_api_key.present? and !self.stripe_api_key.starts_with? TEST_API_KEY_PREFIX
      errors.add(:stripe_api_key, 'must be a stripe test api key')
    end

    if self.public_stripe_api_key.present? and !self.public_stripe_api_key.starts_with? TEST_PUBLIC_API_KEY_PREFIX
      errors.add(:public_stripe_api_key, 'must be a stripe test api key')
    end

  end

end
