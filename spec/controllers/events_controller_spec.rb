# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventsController do
  include SessionSupport

  describe "#async_card" do
    context "when the event is public" do
      let(:event) { create(:event, is_public: true) }

      it "renders successfully for an authenticated organizer" do
        user = create(:user)
        create(:organizer_position, user:, event:)
        sign_in(user)

        get :async_card, params: { event_id: event.slug }

        expect(response).to have_http_status(:ok)
      end

      it "renders successfully for an admin" do
        user = create(:user, :make_admin)
        sign_in(user)

        get :async_card, params: { event_id: event.slug }

        expect(response).to have_http_status(:ok)
      end

      it "renders successfully for an unauthenticated user (public event)" do
        get :async_card, params: { event_id: event.slug }

        expect(response).to have_http_status(:ok)
      end

      it "renders successfully for a non-member (public event)" do
        user = create(:user)
        sign_in(user)

        get :async_card, params: { event_id: event.slug }

        expect(response).to have_http_status(:ok)
      end

      it "renders without layout" do
        get :async_card, params: { event_id: event.slug }

        expect(response).to render_template(layout: false)
        expect(response).to render_template("events/async_card")
      end
    end

    context "when the event is private" do
      let(:event) { create(:event, is_public: false) }

      it "renders successfully for an organizer" do
        user = create(:user)
        create(:organizer_position, user:, event:)
        sign_in(user)

        get :async_card, params: { event_id: event.slug }

        expect(response).to have_http_status(:ok)
      end

      it "renders successfully for an admin" do
        user = create(:user, :make_admin)
        sign_in(user)

        get :async_card, params: { event_id: event.slug }

        expect(response).to have_http_status(:ok)
      end

      it "redirects a non-member" do
        user = create(:user)
        sign_in(user)

        get :async_card, params: { event_id: event.slug }

        expect(response).to be_redirect
      end

      it "redirects an unauthenticated user to login" do
        get :async_card, params: { event_id: event.slug }

        expect(response).to be_redirect
        expect(response.location).to include("sign_in").or include("auth")
      end
    end
  end

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
            "features"  => { "subevents" => true },
          },
          {
            "name"      => "Event 1",
            "slug"      => "event-1",
            "logo"      => "none",
            "demo_mode" => false,
            "member"    => true,
            "features"  => { "subevents" => false },
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
            "features"  => { "subevents" => false },
          },
          {
            "name"      => "Event 2",
            "slug"      => "event-2",
            "logo"      => Rails.application.routes.url_helpers.url_for(event2.logo),
            "demo_mode" => true,
            "member"    => false,
            "features"  => { "subevents" => true },
          },
        ]
      )
    end
  end
end
