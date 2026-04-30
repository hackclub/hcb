# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::FirstController", type: :request do
  let(:valid_form) do
    {
      user: {
        email: "fresh-#{SecureRandom.hex(4)}@example.invalid",
        full_name: "Probe Probe",
        affiliations_attributes: {
          "0" => {
            name: "first",
            league: "FRC",
            team_number: "9999",
            team_name: "Probe Team",
            role: "student_member",
          }
        }
      }
    }
  end

  describe "POST /first" do
    it "responds with a redirect when the supplied email already belongs to an existing user" do
      existing = create(:user, verified: true)

      params = valid_form.deep_dup
      params[:user][:email] = existing.email.upcase

      expect {
        post "/first", params: params
      }.not_to(change { User.count })

      expect(response.status).to be < 500
      expect(response.status).to eq(302)
    end

    it "returns the same response code for taken and fresh emails so registration cannot be enumerated" do
      existing = create(:user, verified: true)

      taken = valid_form.deep_dup
      taken[:user][:email] = existing.email
      post "/first", params: taken
      taken_status = response.status

      fresh = valid_form.deep_dup
      fresh[:user][:email] = "brand-new-#{SecureRandom.hex(4)}@example.invalid"
      post "/first", params: fresh
      fresh_status = response.status

      expect(taken_status).to eq(fresh_status),
                              "Existing-email branch returned #{taken_status} while new-email branch returned #{fresh_status}; " \
                              "this discrepancy lets an attacker enumerate registered emails."
    end

  end

  describe "DELETE /first/sign_out" do
    it "clears the session_token cookie" do
      delete "/first/sign_out"

      set_cookie_header = response.headers["Set-Cookie"].to_s
      expect(set_cookie_header).to match(/session_token=;|session_token=\s*;/i),
                                   "Expected Set-Cookie response to clear session_token, got: #{set_cookie_header.inspect}"
    end
  end

  describe "GET /first" do
    let(:user) { create(:user, verified: true, full_name: "Riley Test") }
    let(:affiliation_metadata) { { "league" => "frc", "team_number" => "9999" } }
    let(:user_role) { "student_member" }

    before do
      user.affiliations.create!(name: "first", metadata: affiliation_metadata.merge("role" => user_role))

      session = create(:user_session, user:, verified: true, expiration_at: 1.hour.from_now)
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)
    end

    context "when the team org exists on HCB" do
      let!(:team_event) { create(:event) }
      let!(:event_affiliation) do
        Event::Affiliation.create!(affiliable: team_event, name: "first", metadata: affiliation_metadata)
      end
      let!(:teammate) { create(:user, verified: true, full_name: "Maya Patel") }
      let!(:teammate_position) { create(:organizer_position, user: teammate, event: team_event) }

      it "renders the teammate avatar inside the Request to join card" do
        get "/first"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Maya")
        expect(response.body).to include("on this team")
      end

      it "does not list the current user in the avatar row when they're not in the org" do
        get "/first"
        expect(response.body).not_to include(">Riley<")
      end
    end

    context "when the team org does not exist but teammates have signed up" do
      let!(:teammate1) { create(:user, verified: true, full_name: "Maya Patel") }
      let!(:teammate2) { create(:user, verified: false, full_name: "Eli Chen") }

      before do
        teammate1.affiliations.create!(name: "first", metadata: affiliation_metadata)
        teammate2.affiliations.create!(name: "first", metadata: affiliation_metadata)
      end

      context "and the user is a student" do
        it "renders teammate avatars inside the AirPods raffle card" do
          get "/first"
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Get a free AirPods Pro 3")
          expect(response.body).to include("Maya")
          expect(response.body).to include("Eli")
          expect(response.body).to include("FRC #9999")
          expect(response.body).to include("are already interested in HCB")
        end

        it "does not render the adults-only standalone card" do
          get "/first"
          expect(response.body).not_to include("Your teammates are interested")
        end
      end

      context "and the user is a head_coach" do
        let(:user_role) { "head_coach" }

        it "renders the standalone teammate card with the start-organization CTA" do
          get "/first"
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Your teammates are interested")
          expect(response.body).to include("are already interested in HCB")
          expect(response.body).to include("Start your team&#39;s organization")
        end
      end

      context "and the user is a mentor_advisor" do
        let(:user_role) { "mentor_advisor" }

        it "renders the standalone teammate card with the start-organization CTA" do
          get "/first"
          expect(response.body).to include("Your teammates are interested")
          expect(response.body).to include("Start your team&#39;s organization")
        end
      end
    end

    context "when no teammates have signed up" do
      it "does not render the teammate sentence" do
        get "/first"
        expect(response.body).not_to include("are already interested in HCB")
        expect(response.body).not_to include("Your teammates are interested")
      end
    end

    context "when the user has no FIRST affiliation" do
      before { user.affiliations.destroy_all }

      it "renders the page without errors" do
        get "/first"
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("are already interested in HCB")
      end
    end
  end
end
