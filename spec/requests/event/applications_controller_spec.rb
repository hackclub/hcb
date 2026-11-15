# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Event::ApplicationsController", type: :request do
  describe "POST /applications" do
    context "when signed out" do
      def return_to_from_redirect
        Rack::Utils.parse_query(URI.parse(response.location).query)["return_to"]
      end

      def referral_code_in(return_to)
        Rack::Utils.parse_query(URI.parse(return_to).query)["referral_code"]
      end

      it "keeps the referral code in return_to so it's saved after signing in" do
        post applications_path, params: { teen_led: "true", referral_code: "hcb-ref-123" }

        return_to = start_applications_path(teen_led: "true", referral_code: "hcb-ref-123")
        expect(response).to redirect_to(auth_users_path(return_to:, require_reload: true, purpose: "application"))
      end

      it "round-trips a referral code containing URL-special characters" do
        post applications_path, params: { teen_led: "true", referral_code: "a&b#c?d" }

        expect(referral_code_in(return_to_from_redirect)).to eq("a&b#c?d")
      end

      it "carries the referral code through to the login form" do
        post applications_path, params: { teen_led: "true", referral_code: "hcb-ref-123" }
        follow_redirect!

        hidden_return_to = Nokogiri::HTML(response.body).at_css("input[name='login[return_to]']")["value"]
        expect(hidden_return_to).to eq(start_applications_path(teen_led: "true", referral_code: "hcb-ref-123"))
      end

      it "leaves a blank referral code out of return_to" do
        post applications_path, params: { teen_led: "true", referral_code: "" }

        expect(return_to_from_redirect).to eq(start_applications_path(teen_led: "true"))
      end

      it "caps the referral code at 100 characters" do
        post applications_path, params: { teen_led: "true", referral_code: "x" * 500 }

        expect(referral_code_in(return_to_from_redirect)).to eq("x" * 100)
      end

      it "ignores a nested referral code instead of erroring" do
        post applications_path, params: { teen_led: "true", referral_code: { nested: "value" } }

        expect(return_to_from_redirect).to eq(start_applications_path(teen_led: "true"))
      end
    end
  end

  describe "GET /applications/start" do
    # The URL a visitor lands on after signing in, via the login's return_to.
    context "when signed in" do
      let(:user) { create(:user, verified: true) }

      before do
        session = create(:user_session, user:, verified: true, expiration_at: 1.hour.from_now)
        allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)
      end

      it "saves the referral code from the query string" do
        get start_applications_path(teen_led: "true", referral_code: "hcb-ref-123")

        application = user.applications.sole
        expect(application.referral_code).to eq("hcb-ref-123")
        expect(application.teen_led).to be(true)
        expect(response).to redirect_to(project_info_application_path(application))
      end

      it "stores a blank referral code as nil" do
        get start_applications_path(teen_led: "true", referral_code: "")

        expect(user.applications.sole.referral_code).to be_nil
      end
    end
  end
end
