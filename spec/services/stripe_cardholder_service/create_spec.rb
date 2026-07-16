# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeCardholderService::Create do
  let(:event) { create(:event) }
  let(:ip_address) { "127.0.0.1" }

  describe "#run" do
    it "raises when phone number is not verified" do
      user = create(:user, phone_number: "+18556254225", phone_number_verified: false)

      service = described_class.new(current_user: user, ip_address:, event_id: event.id)

      expect { service.run }.to raise_error(ArgumentError, /phone number must be verified/)
    end
  end
end
