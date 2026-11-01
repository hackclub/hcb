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

    it "requires a payout method for a managed payee without one" do
      legal_entity = create(:legal_entity, :business, managing_event: event)
      payee = create(:payee, event:, legal_entity:, display_name: "Managed Co")

      get :new, params: { event_id: event.slug, payee_id: payee.hashid }

      expect(response.body).to match(/<input[^>]*required="required"[^>]*name="user\[payout_method_type\]"/)
      expect(response.body).to match(/<input[^>]*required="required"[^>]*name="user\[payout_method_ach_transfer\]\[routing_number\]"/)
      expect(response.body).to match(/<input[^>]*required="required"[^>]*name="user\[payout_method_check\]\[address_line1\]"/)
    end
  end

  describe "POST #create" do
    let(:user) { create(:user) }
    let(:event) { create(:event, organizers: [user]) }

    before do
      Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
      create_session(user, verified: true)
    end

    it "rejects a payment to a managed payee without a payout method" do
      legal_entity = create(:legal_entity, :business, managing_event: event)
      payee = create(:payee, event:, legal_entity:, display_name: "Managed Co")

      expect {
        post :create, params: {
          event_id: event.slug,
          payment: {
            payee_id: payee.hashid,
            amount: "10.00",
            purpose: "Supplies",
            classification: "general_services",
            file: [fixture_file_upload("receipt.png", "image/png")]
          }
        }
      }.not_to change(Payment, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to eq("Please choose a payout method for this payment.")
      expect(legal_entity.reload.default_payout_method).to be_nil
    end
  end
end
