# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventsController do
  include SessionSupport

  describe "#index" do
    before do
      # This is required since creating event configs creates a monthly announcement for the event authored by the system user
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
    end

    it "renders a list of the user's events as json" do
      user = create(:user)

      event1 = create(:event, name: "Event 1")
      create(:organizer_position, user:, event: event1, sort_index: 2)

      event2 = create(:event, name: "Event 2", demo_mode: true)
      create(:organizer_position, user:, event: event2, sort_index: 1)
      event2.create_config!(subevent_plan: Event::Plan::Standard)
      logo_path = Rails.root.join("app/assets/images/logo-production.png")
      event2.logo.attach(io: File.open(logo_path), filename: "logo.png", content_type: "image/png")

      sign_in(user)

      get(:index, format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        [
          {
            "name"      => "Event 2",
            "slug"      => "event-2",
            "logo"      => Rails.application.routes.url_helpers.url_for(event2.logo),
            "demo_mode" => true,
            "member"    => true,
            "features"  => { "card_grants" => false, "subevents" => true },
          },
          {
            "name"      => "Event 1",
            "slug"      => "event-1",
            "logo"      => "none",
            "demo_mode" => false,
            "member"    => true,
            "features"  => { "card_grants" => false, "subevents" => false },
          }
        ]
      )
    end

    it "includes all events if the user is an admin" do
      user = create(:user, :make_admin)

      event1 = create(:event, name: "Event 1")
      create(:organizer_position, user:, event: event1, sort_index: 2)

      event2 = create(:event, name: "Event 2", demo_mode: true)
      event2.create_config!(subevent_plan: Event::Plan::Standard)
      logo_path = Rails.root.join("app/assets/images/logo-production.png")
      event2.logo.attach(io: File.open(logo_path), filename: "logo.png", content_type: "image/png")

      sign_in(user)

      get(:index, format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        [
          {
            "name"      => "Event 1",
            "slug"      => "event-1",
            "logo"      => "none",
            "demo_mode" => false,
            "member"    => true,
            "features"  => { "card_grants" => false, "subevents" => false },
          },
          {
            "name"      => "Event 2",
            "slug"      => "event-2",
            "logo"      => Rails.application.routes.url_helpers.url_for(event2.logo),
            "demo_mode" => true,
            "member"    => false,
            "features"  => { "card_grants" => false, "subevents" => true },
          },
        ]
      )
    end
  end
end
