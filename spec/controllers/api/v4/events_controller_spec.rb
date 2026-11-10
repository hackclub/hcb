# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::EventsController do
  render_views

  describe "#show with expand=users" do
    before do
      allow_any_instance_of(UsersHelper).to receive(:profile_picture_for).and_return("https://gravatar.com/avatar/stubbed")
    end

    it "exposes email of another organizer on the same event" do
      current_user = create(:user, email: "me@example.com")
      other_user   = create(:user, email: "other@example.com")
      event = create(:event)
      create(:organizer_position, user: current_user, event:)
      create(:organizer_position, user: other_user, event:)

      token = create(:api_token, user: current_user)
      request.headers["Authorization"] = "Bearer #{token.token}"

      get :show, params: { id: event.friendly_id, expand: "users" }, as: :json

      expect(response).to have_http_status(:ok)
      other_user_data = response.parsed_body["users"].find { |u| u["id"] == other_user.public_id }
      expect(other_user_data).to include("email" => "other@example.com")
    end

    it "does not expose another organizer's legal name over their preferred name" do
      current_user = create(:user)
      other_user   = create(:user, legal_first_name: "Zebulon", legal_last_name: "Quixley", preferred_name: "Zeb Q")
      event = create(:event)
      create(:organizer_position, user: current_user, event:)
      create(:organizer_position, user: other_user, event:)

      token = create(:api_token, user: current_user)
      request.headers["Authorization"] = "Bearer #{token.token}"

      get :show, params: { id: event.friendly_id, expand: "users" }, as: :json

      other_user_data = response.parsed_body["users"].find { |u| u["id"] == other_user.public_id }
      expect(other_user_data).not_to include("first_name", "last_name")
      expect(response.body).not_to include("Zebulon", "Quixley")
    end

    it "shows another organizer without a preferred name by first name and last initial only" do
      current_user = create(:user)
      other_user   = create(:user, legal_first_name: "Zebulon Xavier", legal_last_name: "Quixley")
      event = create(:event)
      create(:organizer_position, user: current_user, event:)
      create(:organizer_position, user: other_user, event:)

      token = create(:api_token, user: current_user)
      request.headers["Authorization"] = "Bearer #{token.token}"

      get :show, params: { id: event.friendly_id, expand: "users" }, as: :json

      other_user_data = response.parsed_body["users"].find { |u| u["id"] == other_user.public_id }
      expect(other_user_data).to include("name" => "Zebulon Q")
      expect(other_user_data).not_to include("first_name", "last_name")
      expect(response.body).not_to include("Xavier", "Quixley")
    end

    it "exposes the current user's own email and legal name" do
      current_user = create(:user, email: "me@example.com", legal_first_name: "Fiona", legal_last_name: "Hackworth", preferred_name: "FiFi")
      event = create(:event)
      create(:organizer_position, user: current_user, event:)

      token = create(:api_token, user: current_user)
      request.headers["Authorization"] = "Bearer #{token.token}"

      get :show, params: { id: event.friendly_id, expand: "users" }, as: :json

      expect(response).to have_http_status(:ok)
      me = response.parsed_body["users"].find { |u| u["id"] == current_user.public_id }
      expect(me).to include("email" => "me@example.com", "first_name" => "Fiona", "last_name" => "Hackworth")
    end

    it "exposes email of another organizer on the same sub event" do
      current_user = create(:user, email: "me@example.com")
      other_user   = create(:user, email: "other@example.com")
      parent_event = create(:event)
      sub_event    = create(:event)
      sub_event.update!(parent_id: parent_event.id)
      create(:organizer_position, user: current_user, event: sub_event)
      create(:organizer_position, user: other_user, event: sub_event)

      token = create(:api_token, user: current_user)
      request.headers["Authorization"] = "Bearer #{token.token}"

      get :show, params: { id: sub_event.friendly_id, expand: "users" }, as: :json

      expect(response).to have_http_status(:ok)
      other_user_data = response.parsed_body["users"].find { |u| u["id"] == other_user.public_id }
      expect(other_user_data).to include("email" => "other@example.com")
    end

  end

  describe "shares_org_with? helper" do
    let(:helper_instance) do
      ->(user) {
        Class.new do
          include Api::V4::ApplicationHelper

          def initialize(current_user)
            @current_user = current_user
            @expand = []
          end
        end.new(user)
      }
    end

    it "returns false when current_user is nil" do
      helper = helper_instance.call(nil)
      expect(helper.shares_org_with?(create(:user))).to be false
    end

    it "returns false when target user is nil" do
      helper = helper_instance.call(create(:user))
      expect(helper.shares_org_with?(nil)).to be false
    end

    it "returns false when current_user has no readable events" do
      other_user = create(:user)
      create(:organizer_position, user: other_user, event: create(:event))

      helper = helper_instance.call(create(:user))
      expect(helper.shares_org_with?(other_user)).to be false
    end

    it "returns false when users share no events" do
      current_user = create(:user)
      other_user   = create(:user)
      create(:organizer_position, user: current_user, event: create(:event))
      create(:organizer_position, user: other_user,   event: create(:event))

      helper = helper_instance.call(current_user)
      expect(helper.shares_org_with?(other_user)).to be false
    end

    it "returns true when users share an event" do
      current_user = create(:user)
      other_user   = create(:user)
      shared_event = create(:event)
      create(:organizer_position, user: current_user, event: shared_event)
      create(:organizer_position, user: other_user,   event: shared_event)

      helper = helper_instance.call(current_user)
      expect(helper.shares_org_with?(other_user)).to be true
    end

    it "returns true when users share one of several events" do
      current_user = create(:user)
      other_user   = create(:user)
      shared_event = create(:event)
      create(:organizer_position, user: current_user, event: create(:event))
      create(:organizer_position, user: current_user, event: shared_event)
      create(:organizer_position, user: other_user,   event: shared_event)
      create(:organizer_position, user: other_user,   event: create(:event))

      helper = helper_instance.call(current_user)
      expect(helper.shares_org_with?(other_user)).to be true
    end

    it "returns true when current_user manages parent event and target user organizes only a sub event" do
      current_user = create(:user)
      other_user   = create(:user)
      parent_event = create(:event)
      sub_event    = create(:event)
      sub_event.update!(parent_id: parent_event.id)
      create(:organizer_position, user: current_user, event: parent_event)
      create(:organizer_position, user: other_user,   event: sub_event)

      helper = helper_instance.call(current_user)
      expect(helper.shares_org_with?(other_user)).to be true
    end

    it "returns false when current_user organizes only a sub event and target user manages parent event" do
      current_user = create(:user)
      other_user   = create(:user)
      parent_event = create(:event)
      sub_event    = create(:event)
      sub_event.update!(parent_id: parent_event.id)
      create(:organizer_position, user: current_user, event: sub_event)
      create(:organizer_position, user: other_user,   event: parent_event)

      helper = helper_instance.call(current_user)
      expect(helper.shares_org_with?(other_user)).to be false
    end

    it "memoizes current_user's event IDs across multiple calls" do
      current_user = create(:user)
      other_user   = create(:user)
      shared_event = create(:event)
      create(:organizer_position, user: current_user, event: shared_event)
      create(:organizer_position, user: other_user,   event: shared_event)

      helper = helper_instance.call(current_user)
      expect(current_user).to receive(:readable_events).once.and_call_original

      helper.shares_org_with?(other_user)
      helper.shares_org_with?(other_user)
    end
  end
end
