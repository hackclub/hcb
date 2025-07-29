# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncreaseChecksController do
  include SessionSupport
  render_views

  describe "create" do
    it "creates a new check" do
      user = create(:user)
      event = create(:event, :with_positive_balance)
      create(:organizer_position, user:, event:)

      sign_in(user)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          increase_check: {
            amount: "123.45",
            payment_for: "Snacks",
            memo: "Test memo",
            recipient_name: "Orpheus",
            recipient_email: "orpheus@example.com",
            address_line1: "15 Falls Rd.",
            address_line2: "",
            address_city: "Shelburne",
            address_state: "VT",
            address_zip: "05482",
            send_email_notification: "false",
          }
        }
      )

      check = event.increase_checks.sole
      expect(response).to redirect_to(hcb_code_path(check.local_hcb_code))
      expect(check).to be_pending
      expect(check.amount).to eq(123_45)
      expect(check.payment_for).to eq("Snacks")
      expect(check.memo).to eq("Test memo")
      expect(check.recipient_name).to eq("Orpheus")
      expect(check.recipient_email).to eq("orpheus@example.com")
      expect(check.address_line1).to eq("15 Falls Rd.")
      expect(check.address_line2).to eq("")
      expect(check.address_city).to eq("Shelburne")
      expect(check.address_state).to eq("VT")
      expect(check.address_zip).to eq("05482")
      expect(check.send_email_notification).to eq(false)
    end
  end
end
