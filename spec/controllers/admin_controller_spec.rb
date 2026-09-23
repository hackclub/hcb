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

  describe "#reimbursements" do
    render_views

    it "filters by country using the report's currency or the user's phone number" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      us_user = create(:user, phone_number: "+14085551234")
      de_user = create(:user, phone_number: "+491701234567")

      us_report = create(:reimbursement_report, user: us_user, currency: "USD", name: "US report")
      de_report = create(:reimbursement_report, user: de_user, currency: "EUR", name: "DE report")

      get :reimbursements, params: { country: "DE" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(de_report.name)
      expect(response.body).not_to include(us_report.name)
    end

    it "sorts flagged users' reimbursements first" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      flagged_user = create(:user, flagged_at: Time.now)
      normal_user = create(:user)

      normal_report = create(:reimbursement_report, user: normal_user, name: "Normal report", created_at: 1.day.ago)
      flagged_report = create(:reimbursement_report, user: flagged_user, name: "Flagged report", created_at: 2.days.ago)

      get :reimbursements

      expect(response.body.index(flagged_report.name)).to be < response.body.index(normal_report.name)
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
