# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncreaseChecksController do
  include SessionSupport
  render_views

  describe "create" do
    def increase_check_params
      {
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
    end

    it "creates a new check" do
      user = create(:user)
      event = create(:event, :with_positive_balance)
      create(:organizer_position, user:, event:)

      sign_in(user)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          increase_check: increase_check_params,
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

    it "requires sudo mode for transactions over $500" do
      user = create(:user)
      Flipper.enable(:sudo_mode_2015_07_21, user)
      event = create(:event, :with_positive_balance)
      create(:organizer_position, user:, event:)

      sign_in(user)

      travel(3.hours)

      params = {
        event_id: event.friendly_id,
        increase_check: {
          **increase_check_params,
          amount: "500.01",
        }
      }.freeze

      post(:create, params:)

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")
      expect(event.increase_checks).to be_empty

      post(
        :create,
        params: {
          **params,
          _sudo: {
            submit_method: "email",
            login_code: user.login_codes.last.code,
            login_id: user.logins.last.hashid,
          }
        }
      )

      check = event.increase_checks.sole
      expect(response).to redirect_to(hcb_code_path(check.local_hcb_code))
      expect(check.memo).to eq("Test memo")
      expect(check.amount).to eq(500_01)
    end
  end
end
