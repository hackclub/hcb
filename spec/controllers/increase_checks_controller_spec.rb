# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncreaseChecksController do
  include SessionSupport
  render_views

  def build_check_attributes(overrides = {})
    {
      amount: 100_00,
      memo: "Test memo",
      payment_for: "Snacks",
      recipient_name: "Orpheus",
      recipient_email: "orpheus@example.com",
      address_line1: "15 Falls Rd.",
      address_line2: "",
      address_city: "Shelburne",
      address_state: "VT",
      address_zip: "05482",
    }.merge(overrides)
  end

  # describe "stop" do
  #   it "stops a stoppable check" do
  #     user = create(:user)
  #     event = create(:event, :with_positive_balance)
  #     create(:organizer_position, user:, event:)
  #     check = event.increase_checks.create!(
  #       build_check_attributes(column_id: "col_test123", column_status: "issued")
  #     )

  #     sign_in(user)

  #     allow(ColumnService).to receive(:post)
  #       .with("/transfers/checks/col_test123/stop-payment", idempotency_key: "stop_col_test123")
  #       .and_return({ "status" => "stopped", "delivery_status" => "failed" })

  #     post(:stop, params: { id: check.id })

  #     expect(response).to redirect_to(hcb_code_path(check.local_hcb_code))
  #     expect(check.reload.column_status).to eq("stopped")
  #   end

  #   it "denies users without transfer permissions" do
  #     user = create(:user)
  #     event = create(:event, :with_positive_balance)
  #     # no organizer position — user has no access to the event
  #     check = event.increase_checks.create!(
  #       build_check_attributes(column_id: "col_test456", column_status: "issued")
  #     )

  #     sign_in(user)

  #     post(:stop, params: { id: check.id })

  #     expect(response).to redirect_to(root_path)
  #     expect(flash[:error]).to be_present
  #   end

  #   it "denies stopping a check that is not in a stoppable state" do
  #     user = create(:user)
  #     event = create(:event, :with_positive_balance)
  #     create(:organizer_position, user:, event:)
  #     check = event.increase_checks.create!(
  #       build_check_attributes(column_id: "col_test789", column_status: "pending_deposit")
  #     )

  #     sign_in(user)

  #     post(:stop, params: { id: check.id })

  #     expect(response).to redirect_to(root_path)
  #     expect(flash[:error]).to be_present
  #   end
  # end

  # describe "reissue" do
  #   it "copies all attributes to the reissued check" do
  #     user = create(:user, :make_admin)
  #     event = create(:event, :with_positive_balance)
  #     check = event.increase_checks.create!(
  #       build_check_attributes(column_id: "col_original", column_status: "issued")
  #     )

  #     sign_in(user)

  #     allow(ColumnService).to receive(:post)
  #       .with("/transfers/checks/col_original/stop-payment", idempotency_key: "stop_col_original")
  #       .and_return({ "status" => "stopped", "delivery_status" => "failed" })

  #     allow(ColumnService).to receive(:post)
  #       .with(match(/\/account-numbers\z/), anything)
  #       .and_return({ "id" => "acno_test", "account_number" => "123", "routing_number" => "456", "bic" => "789" })

  #     allow(ColumnService).to receive(:post)
  #       .with("/transfers/checks/issue", anything)
  #       .and_return({
  #                     "id"              => "col_new",
  #                     "check_number"    => "1002",
  #                     "status"          => "issued",
  #                     "delivery_status" => "created",
  #                   })

  #     post(:reissue, params: { id: check.id })

  #     new_check = check.reload.reissued_as
  #     expect(response).to redirect_to(hcb_code_path(new_check.local_hcb_code))

  #     columns_that_differ = %w[
  #       id created_at updated_at approved_at aasm_state reissued_for_id
  #       column_id column_status column_delivery_status column_object check_number
  #     ]

  #     columns_to_compare = check.attributes.keys - columns_that_differ

  #     expect(new_check.attributes.slice(*columns_to_compare))
  #       .to eq(check.attributes.slice(*columns_to_compare))
  #   end

  #   it "denies non-admins" do
  #     user = create(:user)
  #     event = create(:event, :with_positive_balance)
  #     create(:organizer_position, user:, event:)
  #     check = event.increase_checks.create!(
  #       build_check_attributes(column_id: "col_test_deny", column_status: "issued")
  #     )

  #     sign_in(user)

  #     post(:reissue, params: { id: check.id })

  #     expect(response).to redirect_to(root_path)
  #     expect(flash[:error]).to be_present
  #   end
  # end

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
