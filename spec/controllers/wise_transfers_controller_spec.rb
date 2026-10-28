# frozen_string_literal: true

require "rails_helper"

RSpec.describe WiseTransfersController do
  include SessionSupport

  def create_wise_transfer(**attrs)
    WiseTransfer.create!(
      event: create(:event),
      user: create(:user),
      amount_cents: 100_00,
      currency: "CAD",
      recipient_country: "CA",
      recipient_name: "Fiona Hackworth",
      recipient_email: "fiona@example.com",
      address_line1: "1 Main Street",
      address_city: "Ottawa",
      address_state: "Ontario",
      address_postal_code: "K1A 0A6",
      payment_for: "Speaker fee",
      account_holder: "Fiona Hackworth",
      bank_name: "Royal Bank of Canada",
      account_type: "bank_account",
      institution_number: "003",
      branch_number: "12345",
      account_number: "1234567",
      # Set so the after_create hook skips generate_quote!, which would
      # otherwise reach for a live exchange rate.
      quoted_usd_amount_cents: 75_00,
      **attrs
    )
  end

  describe "edit" do
    render_views

    it "renders the form with the transfer's current details" do
      admin = create(:user, :make_admin)
      wise_transfer = create_wise_transfer

      create_session(admin, verified: true)

      get :edit, params: { id: wise_transfer.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Fiona Hackworth")
      expect(response.body).to include("1234567")
      expect(response.body).to include('<option selected="selected" value="bank_account">')
    end

    it "is not available once the transfer has been sent" do
      admin = create(:user, :make_admin)
      wise_transfer = create_wise_transfer(
        aasm_state: "sent",
        wise_id: "1234567",
        wise_recipient_id: "0199a1f0-7c3a-4a0b-9b2e-6d1f8a3c5e47",
        usd_amount_cents: 75_00
      )

      create_session(admin, verified: true)

      get :edit, params: { id: wise_transfer.id }

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end
  end

  describe "update" do
    it "updates the recipient and bank details" do
      admin = create(:user, :make_admin)
      wise_transfer = create_wise_transfer(aasm_state: "approved")

      create_session(admin, verified: true)

      patch(
        :update,
        params: {
          id: wise_transfer.id,
          wise_transfer: {
            recipient_name: "Orpheus",
            address_line1: "2 Main Street",
            account_number: "7654321",
          }
        }
      )

      expect(response).to redirect_to(wise_transfer_process_admin_path(wise_transfer))
      expect(flash[:success]).to eq("Edited the Wise transfer.")

      wise_transfer.reload
      expect(wise_transfer.recipient_name).to eq("Orpheus")
      expect(wise_transfer.address_line1).to eq("2 Main Street")
      expect(wise_transfer.account_number).to eq("7654321")
      # Fields that weren't submitted are left alone.
      expect(wise_transfer.institution_number).to eq("003")
      expect(wise_transfer.recipient_email).to eq("fiona@example.com")
    end

    it "does not allow changes once the transfer has been sent" do
      admin = create(:user, :make_admin)
      wise_transfer = create_wise_transfer(
        aasm_state: "sent",
        wise_id: "1234567",
        wise_recipient_id: "0199a1f0-7c3a-4a0b-9b2e-6d1f8a3c5e47",
        usd_amount_cents: 75_00
      )

      create_session(admin, verified: true)

      patch :update, params: { id: wise_transfer.id, wise_transfer: { recipient_name: "Orpheus" } }

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(wise_transfer.reload.recipient_name).to eq("Fiona Hackworth")
    end
  end
end
