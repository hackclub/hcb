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

      create_session(user, verified: true)

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

      create_session(user, verified: true)

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

  describe "#transfers" do
    render_views

    it "lists outgoing disbursements as Disbursement::Outgoing and renders the recipient org" do
      organizer = create(:user)
      event = create(:event)
      create(:organizer_position, user: organizer, event:)

      recipient = create(:event, name: "Receiving Organization")
      create(:disbursement, source_event: event, event: recipient)

      create_session(organizer, verified: true)

      get(:transfers, params: { event_id: event.slug })

      expect(response).to have_http_status(:ok)
      # The recipient-org name only renders in the `is_a?(Disbursement::Outgoing)`
      # branch, so its presence proves @disbursements are Outgoing lenses and the
      # branch renders the destination event.
      expect(response.body).to include("Receiving Organization")
    end
  end

  describe "#ledger" do
    let(:admin) { create(:user, :make_admin) }
    let(:event) { create(:event) }

    before { create_session(admin, verified: true) }

    context "when the organizer has opted into the new ledger" do
      before { Flipper.enable_actor(:new_ledger_2026_07_17, admin) }

      it "renders the new ledger" do
        get(:ledger, params: { event_id: event.slug })

        expect(response).to have_http_status(:ok)
      end

      # The maximum_amount filter used to compile to a malformed `$and` query
      # that raised Ledger::Query::Error inside the action (only Pundit was
      # rescued), 500ing the page. Amount-range filtering itself is covered in
      # the query spec.
      it "accepts the maximum_amount filter without raising" do
        item = create(:ledger_item, amount_cents: 100, datetime: Time.current)
        Ledger::Mapping.create!(ledger: event.ledger, ledger_item: item, on_primary_ledger: true)

        get(:ledger, params: { event_id: event.slug, maximum_amount: 500 })

        expect(response).to have_http_status(:ok)
      end
    end

    context "when the organizer has not opted into the new ledger" do
      it "redirects to the classic transactions page" do
        get(:ledger, params: { event_id: event.slug })

        expect(response).to redirect_to(event_transactions_path(event))
      end
    end

    context "with apply_flipper=true" do
      it "opts the organizer into the new ledger and renders it" do
        get(:ledger, params: { event_id: event.slug, apply_flipper: "true" })

        expect(Flipper.enabled?(:new_ledger_2026_07_17, admin)).to be(true)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "#transactions" do
    let(:admin) { create(:user, :make_admin) }
    let(:event) { create(:event) }

    before { create_session(admin, verified: true) }

    context "when the organizer has opted into the new ledger" do
      before { Flipper.enable_actor(:new_ledger_2026_07_17, admin) }

      it "redirects to the new ledger" do
        get(:transactions, params: { event_id: event.slug })

        expect(response).to redirect_to(event_ledger_path(event))
      end
    end

    context "when the organizer has not opted into the new ledger" do
      it "renders the classic transactions page" do
        get(:transactions, params: { event_id: event.slug })

        expect(response).to have_http_status(:ok)
      end
    end

    context "with apply_flipper=true" do
      before { Flipper.enable_actor(:new_ledger_2026_07_17, admin) }

      it "opts the organizer out of the new ledger and renders the classic page" do
        get(:transactions, params: { event_id: event.slug, apply_flipper: "true" })

        expect(Flipper.enabled?(:new_ledger_2026_07_17, admin)).to be(false)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "#payments" do
    render_views

    it "lists outgoing disbursements as Disbursement::Outgoing and renders the recipient org" do
      organizer = create(:user)
      event = create(:event)
      create(:organizer_position, user: organizer, event:)
      Flipper.enable(:payments_contractors_refresh_2026_06_26, event)

      recipient = create(:event, name: "Receiving Organization")
      create(:disbursement, source_event: event, event: recipient)

      create_session(organizer, verified: true)

      get(:payments, params: { event_id: event.slug })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Receiving Organization")
    end
  end
end
