# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentsController do
  include SessionSupport

  render_views

  describe "GET #new" do
    let(:user) { create(:user) }
    let(:event) { create(:event, organizers: [user]) }

    before do
      Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
      create_session(user, verified: true)
    end

    it "shows the payout/tax steps for a managed payee without recipient-submitted messaging" do
      legal_entity = create(:legal_entity, :business, managing_event: event)
      payee = create(:payee, event:, legal_entity:, display_name: "Managed Co")

      get :new, params: { event_id: event.slug, payee_id: payee.hashid }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Payout method")
      expect(response.body).not_to include("has submitted their payout information")
    end

    it "shows recipient-submitted messaging for a contractor payee" do
      payee = create(:payee, event:, display_name: "Contractor Co")

      get :new, params: { event_id: event.slug, payee_id: payee.hashid }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("has submitted their payout information")
    end
  end

  describe "GET #show" do
    let(:event) { create(:event, :with_positive_balance) }
    let(:legal_entity) { create(:legal_entity, :business) }
    let(:payee) { create(:payee, event:, legal_entity:) }
    let(:payee_user) { create(:user) }

    let(:payment) { create(:payment, :rejected, payee:) }
    let(:wire) { create(:wire, account_number: "DE89370400440532013000", event:) }
    let(:rejection_comment) { "We could not verify the wire details" }

    before do
      stub_request(:get, /api\.column\.com\/institutions/).to_return_json(status: 200, body: { country_code: "DE" })
      create(:legal_entity_user, legal_entity:, user: payee_user)
      create(:payment_attempt, :wire, payment:, payout: wire, aasm_state: "rejected", payout_method: create(:legal_entity_payout_method_wire, details: build(:wire_payout_method_details, account_number: "DE89370400440532013000", bic_code: "DEUTDEDB", recipient_country: :DE, address_city: "Berlin", address_postal_code: "10115", address_state: "Berlin")))
      wire.local_hcb_code.comments.create!(content: rejection_comment, user: create(:user), action: :rejected_transfer)
      create_session(payee_user, verified: true)
    end

    it "shows the admin rejection comment to the payee" do
      get :show, params: { id: payment.hashid }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(rejection_comment)
    end
  end
end
