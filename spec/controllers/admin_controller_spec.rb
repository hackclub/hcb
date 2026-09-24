# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminController do
  include SessionSupport

  describe "#disbursement_process" do
    render_views

    it "renders mission statements for the source and destination events" do
      admin = create(:user, :make_admin)
      source_event = create(:event, description: "Source mission statement")
      destination_event = create(:event, description: "Destination mission statement")
      disbursement = create(:disbursement, source_event:, event: destination_event)

      create_session(admin, verified: true)

      get :disbursement_process, params: { id: disbursement.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Source mission statement")
      expect(response.body).to include("Destination mission statement")
    end
  end

  describe "#set_wise_transfer" do
    it "maps the canonical transaction's ledger item onto the transfer's event ledger" do
      admin = create(:user, :make_admin)
      event = create(:event)
      wise_transfer = WiseTransfer.create!(
        event:,
        user: admin,
        aasm_state: "sent",
        amount_cents: 100_00,
        currency: "GBP",
        recipient_country: "GB",
        recipient_name: "Fiona Hackworth",
        recipient_email: "fiona@example.com",
        payment_for: "Speaker fee",
        # Both are required once the transfer has been sent.
        wise_id: "1234567",
        wise_recipient_id: "0199a1f0-7c3a-4a0b-9b2e-6d1f8a3c5e47",
        # Set so the after_create hook skips generate_quote!, which would
        # otherwise reach for a live exchange rate.
        quoted_usd_amount_cents: 130_00,
        usd_amount_cents: 130_00
      )
      canonical_transaction = create(:canonical_transaction, amount_cents: -130_00)

      create_session(admin, verified: true)

      post :set_wise_transfer, params: { id: canonical_transaction.id, wise_transfer_id: wise_transfer.id }

      expect(wise_transfer.reload).to be_deposited
      expect(canonical_transaction.reload.event).to eq(event)
      expect(canonical_transaction.ledger_item.primary_ledger).to eq(event.ledger)
      expect(canonical_transaction.ledger_item.primary_mapping.mapped_by).to eq(admin)
    end
  end

  describe "#ach_start_approval" do
    render_views

    it "renders the ach transfer event's mission statement" do
      admin = create(:user, :make_admin)
      event = create(:event, :with_positive_balance, description: "Money wiring mission statement")
      ach_transfer = create(:ach_transfer, event:)

      create_session(admin, verified: true)

      get :ach_start_approval, params: { id: ach_transfer.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Money wiring mission statement")
    end
  end
end
