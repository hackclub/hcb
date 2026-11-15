# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::AffiliationsController do
  include SessionSupport

  describe "#create" do
    let(:user) { create(:user) }
    let(:application) { create(:event_application, user:) }

    before do
      create_session(user, verified: true)
      # The form always posts from the application page. `redirect_back`'s
      # fallback (the Event::Application itself) has no matching route helper.
      request.env["HTTP_REFERER"] = project_info_application_url(application)
    end

    it "saves a Destination Imagination affiliation's level, team number, and size" do
      post(:create, params: {
             affiliable_type: "Event::Application",
             affiliable_id: application.id,
             type: "destination_imagination",
             level: "secondary",
             team_number: "125-12345",
             size: "6",
           })

      affiliation = application.affiliations.sole
      expect(affiliation.name).to eq("destination_imagination")
      expect(affiliation.level).to eq("secondary")
      expect(affiliation.team_number).to eq("125-12345")
      expect(affiliation.size).to eq(6)
    end
  end
end
