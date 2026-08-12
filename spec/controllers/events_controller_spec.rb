# frozen_string_literal: true

require "rails_helper"
require "csv"

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

  # XLSX files are zip archives; cell text lives in the shared strings table.
  def xlsx_entry(body, entry)
    Zip::File.open_buffer(StringIO.new(body)).read(entry)
  end

  def xlsx_strings(body)
    Nokogiri::XML(xlsx_entry(body, "xl/sharedStrings.xml")).css("si").map(&:text)
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
  end

  describe "#transactions" do
    let(:admin) { create(:user, :make_admin) }
    let(:event) { create(:event) }

    before { create_session(admin, verified: true) }

    context "when the organizer has not opted into the new ledger" do
      it "renders the classic transactions page" do
        get(:transactions, params: { event_id: event.slug })

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

  describe "#sub_organizations" do
    render_views

    let(:parent) { create(:event, is_public: true, name: "Parent Organization") }
    let!(:transparent_sub) do
      create(:event, parent:, is_public: true, name: "Transparent Sub-organization", slug: "transparent-sub-organization")
    end
    let!(:private_sub) do
      create(:event, parent:, is_public: false, name: "Private Sub-organization", slug: "private-sub-organization")
    end

    context "as a signed out visitor" do
      # The private card's lazy balance frame is what redirected signed out
      # visitors to the login page: it 302s, and Turbo turns the resulting
      # missing frame into a full page visit.
      it "lists only transparent sub-organizations, and loads balances for only those", :aggregate_failures do
        get(:sub_organizations, params: { event_id: parent.slug })

        expect(response.body).to include("Transparent Sub-organization")
        expect(response.body).not_to include("Private Sub-organization")
        expect(response.body).to include(event_async_balance_path(transparent_sub))
        expect(response.body).not_to include(event_async_balance_path(private_sub))
      end

      it "omits private sub-organizations from the graph nodes" do
        get(:sub_organizations, params: { event_id: parent.slug })

        expect(graph_node_names(response.body)).to match_array(["Parent Organization", "Transparent Sub-organization"])
      end

      it "excludes private sub-organizations from the CSV export", :aggregate_failures do
        get(:sub_organizations, params: { event_id: parent.slug }, format: :csv)

        expect(response.body).to include("Transparent Sub-organization")
        expect(response.body).not_to include("Private Sub-organization")
      end

      it "exports the whole subtree with each row's parent, so the tree can be rebuilt", :aggregate_failures do
        grandchild = create(:event, parent: transparent_sub, is_public: true, name: "Transparent Grandchild")

        get(:sub_organizations, params: { event_id: parent.slug }, format: :csv)

        rows = CSV.parse(response.body, headers: true).index_by { |row| row["Name"] }
        expect(rows.keys).to match_array(["Transparent Sub-organization", "Transparent Grandchild"])
        expect(rows["Transparent Sub-organization"]["Parent ID"]).to eq(parent.public_id)
        expect(rows["Transparent Grandchild"]["ID"]).to eq(grandchild.public_id)
        expect(rows["Transparent Grandchild"]["Parent ID"]).to eq(transparent_sub.public_id)
      end

      it "excludes private sub-organizations from the XLSX export", :aggregate_failures do
        get(:sub_organizations, params: { event_id: parent.slug }, format: :xlsx)

        strings = xlsx_strings(response.body)
        expect(strings).to include("Transparent Sub-organization")
        expect(strings).not_to include("Private Sub-organization")
      end
    end

    context "with a hidden sub-organization" do
      let!(:hidden_sub) do
        create(:event, parent:, is_public: true, name: "Hidden Sub-organization", hidden_at: Time.current)
      end

      it "hides it from a signed out visitor" do
        get(:sub_organizations, params: { event_id: parent.slug })

        expect(response.body).not_to include("Hidden Sub-organization")
      end

      context "as an organizer" do
        before { sign_in_organizer_of(parent) }

        it "sets it aside in a collapsed section rather than the main list", :aggregate_failures do
          get(:sub_organizations, params: { event_id: parent.slug })

          document = Nokogiri::HTML5(response.body)
          hidden_section = document.at_css("details#hidden_sub_organizations")
          main_list = document.at_css("ul#sub_organizations")

          expect(hidden_section.text).to include("Hidden Sub-organization")
          expect(main_list.text).not_to include("Hidden Sub-organization")
          expect(main_list.text).to include("Transparent Sub-organization")
        end

        it "omits it from the graph" do
          get(:sub_organizations, params: { event_id: parent.slug })

          expect(graph_node_names(response.body)).not_to include("Hidden Sub-organization")
        end
      end
    end

    context "as an organizer of the parent organization" do
      it "lists every sub-organization", :aggregate_failures do
        sign_in_organizer_of(parent)

        get(:sub_organizations, params: { event_id: parent.slug })

        expect(response.body).to include("Transparent Sub-organization")
        expect(response.body).to include("Private Sub-organization")
      end

      it "renders every descendant as a collapsible tree in the XLSX export", :aggregate_failures do
        nested = create(:event, parent: transparent_sub, is_public: true, name: "Nested Sub-organization")
        sign_in_organizer_of(parent)

        get(:sub_organizations, params: { event_id: parent.slug }, format: :xlsx)

        strings = xlsx_strings(response.body)
        expect(strings).to include("Transparent Sub-organization", "Private Sub-organization")
        # Nested descendants are indented under their parent...
        expect(strings).to include("    #{nested.name}")
        # ...and grouped so Excel renders them collapsible.
        expect(xlsx_entry(response.body, "xl/worksheets/sheet1.xml")).to include('outlineLevel="1"')
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

  describe "#team" do
    render_views

    let(:parent) { create(:event, name: "Parent Organization") }
    let(:event) { create(:event, parent:, name: "Sub Organization") }

    before { sign_in_organizer_of(event) }

    # The callout's list, as { user's displayed name => the role it credits them with }.
    def indirect_access
      get(:team, params: { event_id: event.slug })

      Nokogiri::HTML5(response.body).css("#parent_organization_access .grid > span").to_h do |row|
        [row.at_css(".mention").text.squish, row.text.include?("can manage") ? "manager" : "reader"]
      end
    end

    it "collapses the parent organization callout by default", :aggregate_failures do
      get(:team, params: { event_id: event.slug })

      callout = Nokogiri::HTML5(response.body).at_css("details#parent_organization_access")
      expect(callout.text).to include("The team behind Parent Organization also has access to Sub Organization")
      expect(callout.attributes).not_to have_key("open")
    end

    it "grants a reader on the parent read access here" do
      reader = create(:user)
      create(:organizer_position, user: reader, event: parent, role: :reader)

      expect(indirect_access).to eq({ reader.initial_name => "reader" })
    end

    # A member of the parent only inherits read access here, so their own
    # member position is the higher of the two and already appears in the
    # team list.
    it "grants a member on the parent only read access here" do
      member = create(:user)
      create(:organizer_position, user: member, event: parent, role: :member)

      expect(indirect_access).to eq({ member.initial_name => "reader" })
    end

    it "grants a manager on the parent full management here" do
      manager = create(:user)
      create(:organizer_position, user: manager, event: parent, role: :manager)

      expect(indirect_access).to eq({ manager.initial_name => "manager" })
    end

    it "takes the highest role when the user holds positions on several ancestors" do
      grandparent = create(:event)
      parent.update!(parent: grandparent)
      user = create(:user)
      create(:organizer_position, user:, event: parent, role: :reader)
      create(:organizer_position, user:, event: grandparent, role: :manager)

      expect(indirect_access).to eq({ user.initial_name => "manager" })
    end

    it "omits a user whose position here already matches what they inherit" do
      user = create(:user)
      create(:organizer_position, user:, event: parent, role: :reader)
      create(:organizer_position, user:, event:, role: :reader)

      expect(indirect_access).to eq({})
    end

    it "omits a user whose position here outranks what they inherit" do
      user = create(:user)
      create(:organizer_position, user:, event: parent, role: :member)
      create(:organizer_position, user:, event:, role: :member)

      expect(indirect_access).to eq({})
    end

    it "keeps a user whose inherited role outranks their position here" do
      user = create(:user)
      create(:organizer_position, user:, event: parent, role: :manager)
      create(:organizer_position, user:, event:, role: :member)

      expect(indirect_access).to eq({ user.initial_name => "manager" })
    end

    it "lists managers before readers" do
      reader = create(:user, full_name: "Aaron Reader")
      manager = create(:user, full_name: "Zoe Manager")
      create(:organizer_position, user: reader, event: parent, role: :reader)
      create(:organizer_position, user: manager, event: parent, role: :manager)

      expect(indirect_access.keys).to eq([manager.initial_name, reader.initial_name])
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

  describe "#transactions_list" do
    let(:event) { create(:event, is_public: true) }

    it "serves the unfiltered list to an anonymous reader" do
      get(:transactions_list, params: { event_id: event.slug })

      expect(response).to have_http_status(:success)
    end

    it "rejects a filter from an anonymous reader before reaching the transaction engines" do
      expect(TransactionGroupingEngine::Transaction::All).not_to receive(:new)
      expect(PendingTransactionEngine::PendingTransaction::All).not_to receive(:new)

      get(:transactions_list, params: { event_id: event.slug, direction: "revenue" })

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects every filter param from an anonymous reader" do
      SetLedgerFilters::FILTER_PARAMS.each do |param|
        get(:transactions_list, params: { event_id: event.slug, param => "x" })

        expect(response).to have_http_status(:bad_request), "expected #{param} to be rejected"
      end
    end

    it "allows a filter from a signed-in organizer" do
      sign_in_organizer_of(event)

      get(:transactions_list, params: { event_id: event.slug, direction: "revenue" })

      expect(response).to have_http_status(:success)
    end
  end

end
