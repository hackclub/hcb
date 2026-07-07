# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentsController do
  include SessionSupport

  render_views

  describe "GET #new" do
    it "renders the manual flow copy without recipient-submitted messaging" do
      user = create(:user)
      event = create(:event, organizers: [user])
      Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
      create_session(user, verified: true)

      get :new, params: { event_id: event.slug, manual: "true" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Payout method")
      expect(response.body).to include("Recipient type")
      expect(response.body).not_to include("has submitted their tax information")
    end
  end
end
