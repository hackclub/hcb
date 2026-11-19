# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PaperTrail attribution tracking", type: :request, versioning: true do
  let(:user) { create(:user, full_name: "Original Name") }

  describe "cookie sessions" do
    def sign_in_with(session)
      allow_any_instance_of(SessionsHelper)
        .to receive(:find_current_session)
        .and_return(session)
    end

    it "records the session on versions created during the request" do
      session = create(:user_session, user:, expiration_at: 1.hour.from_now)
      sign_in_with(session)

      patch "/users/#{user.id}", params: { user: { full_name: "Changed Name" } }

      version = user.versions.last
      expect(version.whodunnit).to eq(user.id.to_s)
      expect(version.user_session_id).to eq(session.id)
      expect(version.api_token_id).to be_nil
    end

    it "leaves the session blank on versions created without one" do
      sign_in_with(nil)

      patch "/users/#{user.id}", params: { user: { full_name: "Changed Name" } }

      expect(user.versions.last.user_session_id).to be_nil
    end
  end

  describe "api tokens" do
    let(:organizer) { create(:user) }
    let(:token) { create(:api_token, user: organizer) }
    let(:event) { create(:event) }

    before { create(:organizer_position, user: organizer, event:, role: :manager) }

    it "records the token on versions created during the request" do
      post "/api/v4/organizations/#{event.id}/invitations",
           params: { email: "invitee@example.com", role: "member" },
           headers: { "Authorization" => "Bearer #{token.token}" }

      expect(response).to have_http_status(:created)

      version = PaperTrail::Version.where(event: "create", item_type: "OrganizerPositionInvite").order(:id).last
      expect(version.whodunnit).to eq(organizer.id.to_s)
      expect(version.api_token_id).to eq(token.id)
      expect(version.user_session_id).to be_nil
    end
  end
end
