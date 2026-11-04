# frozen_string_literal: true

require "rails_helper"

RSpec.describe "remembered organizations", type: :request do
  let(:user) { create(:user) }

  def stub_current_session(user_session)
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(user_session)
  end

  def data_value(name)
    Nokogiri::HTML(response.body)
            .at_css("[data-controller~='remembered-organizations']")
            &.[]("data-remembered-organizations-#{name}-value")
  end

  context "when signed in" do
    before { stub_current_session(create(:user_session, user:, expiration_at: 1.hour.from_now)) }

    it "lists transparent organizations and their sub-organizations, excluding private ones" do
      parent = create(:event, organizers: [user], is_public: true)
      child = create(:event, parent:, is_public: true)
      private_event = create(:event, organizers: [user], is_public: false)

      get event_path(parent)

      ids = JSON.parse(data_value("event-ids"))
      expect(ids).to contain_exactly(parent.public_id, child.public_id)
      expect(ids).not_to include(private_event.public_id)
    end

    it "flags the next page to clear them after an explicit sign out" do
      event = create(:event, is_public: true)

      delete logout_users_path
      stub_current_session(nil)
      get event_path(event)

      expect(data_value("clear")).to eq("true")
    end
  end

  context "when impersonating" do
    it "does not overwrite the admin's list" do
      admin = create(:user, :make_admin)
      event = create(:event, organizers: [user], is_public: true)
      impersonation_session = create(:user_session, user:, impersonated_by: admin, expiration_at: 1.hour.from_now)
      stub_current_session(impersonation_session)

      get event_path(event)

      expect(data_value("event-ids")).to be_nil
    end
  end

  context "when signed out" do
    it "exposes the current transparent organization without clearing" do
      event = create(:event, is_public: true)

      get event_path(event)

      expect(data_value("current-event")).to eq(event.public_id)
      expect(data_value("clear")).to be_nil
    end

    it "returns to the organization after signing in" do
      event = create(:event, is_public: true)

      get event_path(event)

      sign_in_link = Nokogiri::HTML(response.body).at_css("[data-remembered-organizations-target='signIn']")
      expect(sign_in_link["href"]).to eq(auth_users_path(return_to: event_url(event)))
    end
  end
end
