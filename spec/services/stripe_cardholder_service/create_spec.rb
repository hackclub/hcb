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

    it "raises when phone number is verified but event is unapproved" do
      user = create(:user, phone_number: "+18556254225", phone_number_verified: true)
      unapproved_event = create(:event)
      unapproved_event.update_column(:aasm_state, "unapproved")

      service = described_class.new(current_user: user, ip_address:, event_id: unapproved_event.id)

      expect { service.run }.to raise_error(ArgumentError, /not permitted under spend only plan/)
    end
  end
end
