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

      get :new, params: { event_id: event.slug, payee_id: payee.public_id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Payout method")
      expect(response.body).to include("Tax information")
      expect(response.body).not_to include("has submitted their tax information")
    end

    it "shows recipient-submitted messaging for a contractor payee" do
      payee = create(:payee, event:, display_name: "Contractor Co")

      get :new, params: { event_id: event.slug, payee_id: payee.public_id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("has submitted their tax information")
    end
  end
end
