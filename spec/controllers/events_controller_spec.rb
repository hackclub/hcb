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
    render_views

    let(:admin) { create(:user, :make_admin) }
    let(:event) { create(:event) }

    before { create_session(admin, verified: true) }

    # The maximum_amount filter used to compile to a malformed `$and` query that
    # raised Ledger::Query::Error inside the action (only Pundit was rescued),
    # 500ing the page. Amount-range filtering itself is covered in the query spec.
    it "accepts the maximum_amount filter without raising" do
      item = create(:ledger_item, amount_cents: 100, datetime: Time.current)
      Ledger::Mapping.create!(ledger: event.ledger, ledger_item: item, on_primary_ledger: true)

      get(:ledger, params: { event_id: event.slug, maximum_amount: 500 })

      expect(response).to have_http_status(:ok)
    end

    it "shows the merchant name in the active-filter badge, resolved from a card charge's pending transaction" do
      # Creating a RawPendingStripeTransaction auto-creates its CardCharge
      # (RawPendingStripeTransaction#link_card_charge!), so use that rather
      # than creating a second CardCharge for the same transaction.
      raw_pending = create(:raw_pending_stripe_transaction, stripe_transaction: { "merchant_data" => { "name" => "merchant 1", "network_id" => "555000111" } })
      item = create(:ledger_item, linked_object: raw_pending.card_charge)
      Ledger::Mapping.create!(ledger: event.ledger, ledger_item: item, on_primary_ledger: true)

      get(:ledger, params: { event_id: event.slug, merchant: "555000111" })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Merchant 1")
    end

    it "falls back to a generic badge label when the merchant isn't found on this ledger" do
      get(:ledger, params: { event_id: event.slug, merchant: "000000000" })

      expect(response.body).to include("Merchant 000000000")
    end
  end

  describe "#merchants_filter" do
    render_views

    let(:admin) { create(:user, :make_admin) }
    let(:event) { create(:event) }

    before { create_session(admin, verified: true) }

    def create_card_charge_item(ledger, network_id:, name:, settled: false)
      raw_pending = create(:raw_pending_stripe_transaction, stripe_transaction: { "merchant_data" => { "name" => name, "network_id" => network_id } })
      card_charge = raw_pending.card_charge
      if settled
        # Creating a RawStripeTransaction with a matching stripe_authorization_id
        # auto-links it to the existing card charge (RawStripeTransaction#link_card_charge!).
        # Uses the factory's own card/cardholder defaults (Ledger::Item#refresh!
        # resolves the item's author through them) and only overrides merchant_data.
        rst = create(:raw_stripe_transaction, stripe_authorization_id: raw_pending.stripe_transaction_id)
        rst.update_columns(stripe_transaction: rst.stripe_transaction.merge("merchant_data" => { "name" => name, "network_id" => network_id }))
      end
      item = create(:ledger_item, linked_object: card_charge)
      Ledger::Mapping.create!(ledger:, ledger_item: item, on_primary_ledger: true)
      item
    end

    it "lists distinct merchants from both settled and pending card charges, most-transacted first" do
      create_card_charge_item(event.ledger, network_id: "111", name: "bakery", settled: true)
      create_card_charge_item(event.ledger, network_id: "111", name: "bakery", settled: true)
      create_card_charge_item(event.ledger, network_id: "222", name: "bookstore", settled: false)

      get(:merchants_filter, params: { event_id: event.slug })

      expect(response.body).to include("Bakery")
      expect(response.body).to include("Bookstore")
      # Bakery has 2 matching card charges vs. Bookstore's 1, so it renders first.
      expect(response.body.index("Bakery")).to be < response.body.index("Bookstore")
    end

    it "counts each merchant's card charges" do
      create_card_charge_item(event.ledger, network_id: "111", name: "bakery", settled: true)
      create_card_charge_item(event.ledger, network_id: "111", name: "bakery", settled: true)
      create_card_charge_item(event.ledger, network_id: "222", name: "bookstore", settled: false)

      merchants = controller.send(:ledger_merchants, [event.ledger])

      expect(merchants).to match_array([
                                         { id: "111", name: "Bakery", count: 2 },
                                         { id: "222", name: "Bookstore", count: 1 },
                                       ])
    end

    it "does not include another event's ledger in the merchant list" do
      create_card_charge_item(event.ledger, network_id: "111", name: "bakery")

      other_event = create(:event)
      create_card_charge_item(other_event.ledger, network_id: "999", name: "other org's merchant")

      get(:merchants_filter, params: { event_id: event.slug })

      expect(response.body).to include("Bakery")
      expect(response.body).not_to match(/other org/i)
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
