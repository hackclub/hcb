# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventsController do
  include SessionSupport

  # The graph's node list is inlined as a JSON Stimulus value on the page.
  def graph_node_names(body)
    attribute = Nokogiri::HTML5(body)
                        .at_css("[data-controller='sub-organizations-graph']")
                        .attr("data-sub-organizations-graph-nodes-value")

    JSON.parse(attribute).pluck("name")
  end

  def money(cents)
    ApplicationController.helpers.render_money_amount(cents)
  end

  def sign_in_organizer_of(event)
    organizer = create(:user)
    create(:organizer_position, user: organizer, event:)
    create_session(organizer, verified: true)
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

  describe "#sub_organizations" do
    render_views

    let(:parent) { create(:event, is_public: true, name: "Parent Organization") }
    let!(:transparent_sub) do
      create(:event, parent:, is_public: true, name: "Transparent Subsidiary", slug: "transparent-subsidiary")
    end
    let!(:private_sub) do
      create(:event, parent:, is_public: false, name: "Private Subsidiary", slug: "private-subsidiary")
    end

    context "as a signed out visitor" do
      # The private card's lazy balance frame is what redirected signed out
      # visitors to the login page: it 302s, and Turbo turns the resulting
      # missing frame into a full page visit.
      it "lists only transparent sub-organizations, and loads balances for only those", :aggregate_failures do
        get(:sub_organizations, params: { event_id: parent.slug })

        expect(response.body).to include("Transparent Subsidiary")
        expect(response.body).not_to include("Private Subsidiary")
        expect(response.body).to include(event_async_balance_path(transparent_sub))
        expect(response.body).not_to include(event_async_balance_path(private_sub))
      end

      it "omits private sub-organizations from the graph nodes" do
        get(:sub_organizations, params: { event_id: parent.slug })

        expect(graph_node_names(response.body)).to match_array(["Parent Organization", "Transparent Subsidiary"])
      end

      it "excludes private sub-organizations from the CSV export", :aggregate_failures do
        get(:sub_organizations, params: { event_id: parent.slug }, format: :csv)

        expect(response.body).to include("Transparent Subsidiary")
        expect(response.body).not_to include("Private Subsidiary")
      end
    end

    context "with a hidden sub-organization" do
      let!(:hidden_sub) do
        create(:event, parent:, is_public: true, name: "Hidden Subsidiary", hidden_at: Time.current)
      end

      it "hides it from a signed out visitor" do
        get(:sub_organizations, params: { event_id: parent.slug })

        expect(response.body).not_to include("Hidden Subsidiary")
      end

      context "as an organizer" do
        before { sign_in_organizer_of(parent) }

        it "sets it aside in a collapsed section rather than the main list", :aggregate_failures do
          get(:sub_organizations, params: { event_id: parent.slug })

          document = Nokogiri::HTML5(response.body)
          hidden_section = document.at_css("details#hidden_sub_organizations")
          main_list = document.at_css("ul#sub_organizations")

          expect(hidden_section.text).to include("Hidden Subsidiary")
          expect(main_list.text).not_to include("Hidden Subsidiary")
          expect(main_list.text).to include("Transparent Subsidiary")
        end

        it "omits it from the graph" do
          get(:sub_organizations, params: { event_id: parent.slug })

          expect(graph_node_names(response.body)).not_to include("Hidden Subsidiary")
        end
      end
    end

    context "as an organizer of the parent organization" do
      it "lists every sub-organization", :aggregate_failures do
        sign_in_organizer_of(parent)

        get(:sub_organizations, params: { event_id: parent.slug })

        expect(response.body).to include("Transparent Subsidiary")
        expect(response.body).to include("Private Subsidiary")
      end
    end
  end

  describe "#async_sub_organizations_graph" do
    let(:parent) { create(:event, is_public: true) }
    let!(:transparent_sub) { create(:event, parent:, is_public: true) }
    let!(:private_sub) { create(:event, parent:, is_public: false) }

    it "omits private sub-organizations from a signed out visitor" do
      get(:async_sub_organizations_graph, params: { event_id: parent.slug })

      expect(response.parsed_body.pluck("id")).to match_array([parent.id, transparent_sub.id])
    end

    it "includes private sub-organizations for an organizer of the parent" do
      sign_in_organizer_of(parent)

      get(:async_sub_organizations_graph, params: { event_id: parent.slug })

      expect(response.parsed_body.pluck("id")).to match_array([parent.id, transparent_sub.id, private_sub.id])
    end

    # The cache entry is shared by every viewer, so filtering has to happen on
    # the way out rather than being baked into what was cached.
    it "filters private sub-organizations out of a cache entry that holds them" do
      store = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(store)
      store.write("sub_organizations_graph_#{parent.id}", [parent, transparent_sub, private_sub].map do |event|
        { id: event.id, balance_cents: 500, card_count: 3 }
      end)

      get(:async_sub_organizations_graph, params: { event_id: parent.slug })

      expect(response.parsed_body.pluck("id")).to match_array([parent.id, transparent_sub.id])
    end
  end

  describe "#async_sub_organization_balance" do
    render_views

    let(:parent) { create(:event, is_public: true) }
    let!(:transparent_sub) { create(:event, :with_positive_balance, parent:, is_public: true) }
    let!(:private_sub) { create(:event, :with_positive_balance, parent:, is_public: false) }

    it "sums only transparent sub-organizations for a signed out visitor", :aggregate_failures do
      get(:async_sub_organization_balance, params: { event_id: parent.slug })

      expect(response.body).to include(money(transparent_sub.balance_available_v2_cents))
      expect(response.body).not_to include(
        money(transparent_sub.balance_available_v2_cents + private_sub.balance_available_v2_cents)
      )
    end

    it "sums every sub-organization for an organizer of the parent" do
      sign_in_organizer_of(parent)

      get(:async_sub_organization_balance, params: { event_id: parent.slug })

      expect(response.body).to include(
        money(transparent_sub.balance_available_v2_cents + private_sub.balance_available_v2_cents)
      )
    end
  end

end
