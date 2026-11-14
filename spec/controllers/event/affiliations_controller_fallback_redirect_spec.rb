# frozen_string_literal: true

require "rails_helper"

# With no referrer, `redirect_back` uses its fallback location. For an
# Event::Application, that fallback used to raise NoMethodError
# (`event_application_url`) because applications are routed as `application`.
RSpec.describe Event::AffiliationsController do
  include SessionSupport

  let(:user) { create(:user) }
  let(:application) { create(:event_application, user:) }

  before { create_session(user, verified: true) }

  describe "#create" do
    it "falls back to the application when there's no referrer" do
      post(:create, params: {
             affiliable_type: "Event::Application",
             affiliable_id: application.id,
             type: "first",
             league: "frc",
             team_number: "9101",
             size: "10",
           })

      expect(response).to redirect_to(application_path(application))
      expect(application.affiliations.sole.team_number).to eq("9101")
    end
  end

  context "with an existing affiliation" do
    let!(:affiliation) do
      Event::Affiliation.create!(
        name: "first",
        metadata: { league: "frc", team_number: "9101", size: 10 },
        affiliable: application
      )
    end

    describe "#update" do
      it "falls back to the application when there's no referrer" do
        patch(:update, params: { id: affiliation.id, type: "first", league: "ftc", team_number: "1234", size: "8" })

        expect(response).to redirect_to(application_path(application))
        expect(affiliation.reload.league).to eq("ftc")
      end
    end

    describe "#destroy" do
      it "falls back to the application when there's no referrer" do
        delete(:destroy, params: { id: affiliation.id })

        expect(response).to redirect_to(application_path(application))
        expect(Event::Affiliation.exists?(affiliation.id)).to be(false)
      end
    end
  end
end
