# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::FirstController#verify_email", type: :request do
  let(:unverified_user) { create(:user, verified: false, creation_method: :first_robotics_form) }
  let(:unverified_session) { create(:user_session, user: unverified_user, verified: false) }

  describe "GET /first/verify_email" do
    before do
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(unverified_session)
    end

    it "does not start a verification flow" do
      expect {
        get "/first/verify_email"
      }.not_to change(Login, :count)
    end
  end

  describe "POST /first/verify_email" do
    context "for an unverified user" do
      before do
        allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(unverified_session)
      end

      it "starts a verification flow for the user" do
        expect {
          post "/first/verify_email"
        }.to change { Login.where(user: unverified_user).count }.by(1)
      end

      it "redirects to choose a login factor" do
        post "/first/verify_email"

        login = Login.where(user: unverified_user).last
        expect(response).to redirect_to(choose_login_preference_login_path(login))
      end
    end

    context "for an anonymous request" do
      it "does not start a verification flow" do
        expect {
          post "/first/verify_email"
        }.not_to change(Login, :count)
      end

      it "redirects to the welcome page" do
        post "/first/verify_email"

        expect(response).to redirect_to(welcome_first_index_path)
      end
    end

    context "for a verified user" do
      let(:verified_user) { create(:user, verified: true) }
      let(:verified_session) { create(:user_session, user: verified_user, verified: true) }

      before do
        allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(verified_session)
      end

      it "does not start a verification flow" do
        expect {
          post "/first/verify_email"
        }.not_to change(Login, :count)
      end

      it "redirects to the welcome page" do
        post "/first/verify_email"

        expect(response).to redirect_to(welcome_first_index_path)
      end
    end
  end
end
