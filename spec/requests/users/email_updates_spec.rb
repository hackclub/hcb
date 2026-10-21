# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::EmailUpdatesController", type: :request do
  let(:user) { create(:user) }
  let(:user_session) { create(:user_session, user:) }

  before do
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(user_session)
  end

  describe "GET /email_updates/authorize" do
    it "redirects with an error for an unknown authorization token" do
      get authorize_email_updates_path(authorization_token: "does-not-exist")

      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("This authorization token has expired, please request another.")
    end
  end

  describe "GET /email_updates/verify" do
    it "redirects with an error for an unknown verification token" do
      get verify_email_updates_path(verification_token: "does-not-exist")

      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("This authorization token has expired, please request another.")
    end
  end
end
