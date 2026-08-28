# frozen_string_literal: true

require "rails_helper"
require "csv"

RSpec.describe EventsController do
  include SessionSupport

  def table_rows(body)
    Nokogiri::HTML5("<table><tbody>#{body}</tbody></table>").css("tr.sub-organization-row")
  end

  def table_row_names(body)
    table_rows(body).css(".sub-organization-row__title").map(&:text)
  end

  def money(cents)
    ApplicationController.helpers.render_money_amount(cents)
  end

  def dom_id_for_balance(event)
    "event_balance_#{event.public_id}"
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
    render_views

    let(:admin) { create(:user, :make_admin) }
    let(:event) { create(:event) }

    before { create_session(admin, verified: true) }

    context "when the user has opted into the new ledger" do
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

      # The default status filter hides declined/failed/rejected/canceled/
      # released items, but a non-zero amount should trump that: e.g. a
      # declined card charge that still posted a partial hold must still show.
      #
      # `status`/`amount_cents`/`memo` are derived columns recalculated by
      # Ledger::Item#refresh! (triggered by Ledger::Mapping's after_commit)
      # whenever a bare, unlinked item is created or mapped — `memo` in
      # particular falls back to custom_memo/system_memo/fallback_memo, so the
      # factory's plain `memo:` gets overwritten. Set `custom_memo` so it
      # survives refresh, and set status/amount_cents via update_columns
      # (bypasses callbacks) after mapping, to simulate a real
      # declined-but-moved-money item.
      it "shows a non-settled item with a non-zero amount, but hides one with a zero amount" do
        moved_money = create(:ledger_item, custom_memo: "Declined but moved money", datetime: Time.current)
        Ledger::Mapping.create!(ledger: event.ledger, ledger_item: moved_money, on_primary_ledger: true)
        moved_money.update_columns(status: "declined", amount_cents: 500, ct_count: 1)

        no_money_moved = create(:ledger_item, custom_memo: "Declined with no amount", datetime: Time.current)
        Ledger::Mapping.create!(ledger: event.ledger, ledger_item: no_money_moved, on_primary_ledger: true)
        no_money_moved.update_columns(status: "declined", amount_cents: 0, ct_count: 1)

        get(:ledger, params: { event_id: event.slug })

        expect(response.body).to include("Declined but moved money")
        expect(response.body).not_to include("Declined with no amount")
      end
    end
  end

  describe "#ledger_stats" do
    render_views

    let(:admin) { create(:user, :make_admin) }
    let(:event) { create(:event) }

    before { create_session(admin, verified: true) }

    it "sums ledger items by sign for revenue and expenses" do
      revenue_item = create(:ledger_item, custom_memo: "Revenue item", datetime: Time.current)
      Ledger::Mapping.create!(ledger: event.ledger, ledger_item: revenue_item, on_primary_ledger: true)
      revenue_item.update_columns(status: "settled", amount_cents: 1500)

      expense_item = create(:ledger_item, custom_memo: "Expense item", datetime: Time.current)
      Ledger::Mapping.create!(ledger: event.ledger, ledger_item: expense_item, on_primary_ledger: true)
      expense_item.update_columns(status: "settled", amount_cents: -600)

      get(:ledger_stats, params: { event_id: event.slug })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(money(1500)) # total revenue
      expect(response.body).to include(money(600))  # total expenses, shown positive
      expect(response.body).to include(money(900))  # account balance (1500 - 600)
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

  describe "#edit" do
    render_views

    # Creating, editing and deleting tags are member-level server side, so the
    # settings tab shouldn't present them as manager-only.
    it "lets a member manage tags from the settings tab" do
      member = create(:user)
      event = create(:event)
      create(:organizer_position, user: member, event:, role: :member)
      event.tags.create!(label: "Snacks", color: "muted", emoji: "🍕")
      create_session(member, verified: true)

      get(:edit, params: { id: event.slug, tab: "tags" })
      page = Nokogiri::HTML5(response.body)

      expect(page.css("#tags_settings input[name='label'][disabled]")).to be_empty
      expect(page.css("#tags_settings a[disabled]")).to be_empty
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
      it "lists only transparent sub-organizations, with a balance frame for only those", :aggregate_failures do
        get(:sub_organizations, params: { event_id: parent.slug })

        document = Nokogiri::HTML5(response.body)

        expect(response.body).to include("Transparent Sub-organization")
        expect(response.body).not_to include("Private Sub-organization")
        expect(document.at_css("##{dom_id_for_balance(transparent_sub)}")).to be_present
        expect(document.at_css("##{dom_id_for_balance(private_sub)}")).to be_nil
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
          get(:sub_organizations, params: { event_id: parent.slug, view: "grid" })

          document = Nokogiri::HTML5(response.body)
          hidden_section = document.at_css("details#hidden_sub_organizations")
          main_list = document.at_css("ul#sub_organizations")

          expect(hidden_section.text).to include("Hidden Sub-organization")
          expect(main_list.text).not_to include("Hidden Sub-organization")
          expect(main_list.text).to include("Transparent Sub-organization")
        end

        # The tree keeps them in place rather than in their own section.
        it "lists it inline in the table view, badged as hidden", :aggregate_failures do
          get(:sub_organizations, params: { event_id: parent.slug, view: "list" })

          row = Nokogiri::HTML5(response.body).at_css("tr#sub_organization_row_#{hidden_sub.public_id}")

          expect(table_row_names(response.body)).to include("Hidden Sub-organization")
          expect(row.css(".badge").map { |badge| badge.text.strip }).to include("Hidden")
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
        sheet = xlsx_entry(response.body, "xl/worksheets/sheet1.xml")
        expect(sheet).to include('outlineLevel="1"')
        # Descendants start hidden, and every row with children carries the
        # collapsed flag, so the tree opens fully collapsed.
        expect(sheet).to include('hidden="1"')
        expect(sheet).to include('collapsed="1"')
        # Excel hides the grouping gutter entirely when this attribute is set,
        # even though Google Sheets ignores it. See SubOrganizationsExport.
        expect(sheet).not_to include("showOutlineSymbols")
      end
    end
  end

  describe "#sub_organizations, in the table view" do
    render_views

    let(:parent) { create(:event, is_public: true, name: "Parent Organization") }
    let!(:transparent_sub) do
      create(:event, parent:, is_public: true, name: "Transparent Sub-organization", slug: "transparent-sub-organization")
    end
    let!(:private_sub) do
      create(:event, parent:, is_public: false, name: "Private Sub-organization", slug: "private-sub-organization")
    end

    it "starts collapsed at the immediate sub-organizations", :aggregate_failures do
      grandchild = create(:event, parent: transparent_sub, is_public: true, name: "Transparent Grandchild")

      get(:sub_organizations, params: { event_id: parent.slug, view: "list" })

      expect(table_row_names(response.body)).to eq(["Transparent Sub-organization"])
      expect(response.body).not_to include(grandchild.name)
    end

    it "omits private sub-organizations from a signed out visitor" do
      get(:sub_organizations, params: { event_id: parent.slug, view: "list" })

      expect(table_row_names(response.body)).to eq(["Transparent Sub-organization"])
    end

    # Event's default scope orders by id, which plain `order` would not displace.
    it "sorts the rows by name" do
      create(:event, parent:, is_public: true, name: "Anchor Sub-organization")
      create(:event, parent:, is_public: true, name: "Middle Sub-organization")

      get(:sub_organizations, params: { event_id: parent.slug, view: "list" })

      expect(table_row_names(response.body)).to eq(
        ["Anchor Sub-organization", "Middle Sub-organization", "Transparent Sub-organization"]
      )
    end

    it "lists private sub-organizations for an organizer, badged as private", :aggregate_failures do
      sign_in_organizer_of(parent)

      get(:sub_organizations, params: { event_id: parent.slug, view: "list" })

      row = Nokogiri::HTML5(response.body).at_css("tr#sub_organization_row_#{private_sub.public_id}")

      expect(table_row_names(response.body)).to match_array(["Transparent Sub-organization", "Private Sub-organization"])
      expect(row.css(".badge").map { |badge| badge.text.strip }).to include("Private")
    end

    # An unexpandable row looks like a leaf; an expander would give it away.
    it "offers no expander for a branch whose sub-organizations are all private" do
      create(:event, parent: transparent_sub, is_public: false, name: "Private Grandchild")

      get(:sub_organizations, params: { event_id: parent.slug, view: "list" })

      row = Nokogiri::HTML5(response.body).at_css("tr#sub_organization_row_#{transparent_sub.public_id}")
      expect(row.at_css("button.sub-organization-row__toggle")).to be_nil
    end

    it "offers an expander to an organizer who can see the private sub-organizations" do
      create(:event, parent: transparent_sub, is_public: false, name: "Private Grandchild")
      sign_in_organizer_of(parent)

      get(:sub_organizations, params: { event_id: parent.slug, view: "list" })

      row = Nokogiri::HTML5(response.body).at_css("tr#sub_organization_row_#{transparent_sub.public_id}")
      expect(row.at_css("button.sub-organization-row__toggle")).to be_present
    end

    # The expander has to sit outside the row-wide link, or it would navigate.
    it "links the whole row, with the expander alongside the link", :aggregate_failures do
      create(:event, parent: transparent_sub, is_public: true, name: "Transparent Grandchild")

      get(:sub_organizations, params: { event_id: parent.slug, view: "list" })

      row = Nokogiri::HTML5(response.body).at_css("tr#sub_organization_row_#{transparent_sub.public_id}")

      expect(row["class"]).to include("clickable")
      expect(row.at_css("a.stretched-link")["href"]).to eq("/#{transparent_sub.slug}")
      expect(row.at_css("button.sub-organization-row__toggle")).to be_present
      expect(row.at_css(".sub-organization-row__title").name).to eq("span")
    end

    # Inside the table, a sticky element would stick to its horizontal scroll.
    it "wires up the bar that pins the organizations you are scrolled inside of", :aggregate_failures do
      get(:sub_organizations, params: { event_id: parent.slug, view: "list" })

      document = Nokogiri::HTML5(response.body)
      controller = document.at_css("[data-controller='sub-organization-tree']")

      expect(controller.at_css("[data-sub-organization-tree-target='pinned']")).to be_present
      expect(controller.at_css("table")).to be_present
      expect(controller.at_css(".table-container [data-sub-organization-tree-target='pinned']")).to be_nil
      expect(controller["data-action"].split)
        .to include("scroll@window->sub-organization-tree#repin:passive")
    end

    it "remembers the chosen view between visits" do
      get(:sub_organizations, params: { event_id: parent.slug, view: "list" })
      get(:sub_organizations, params: { event_id: parent.slug })

      expect(response.body).to include("sub-organization-row")
    end
  end

  describe "#async_sub_organization_rows" do
    render_views

    let(:parent) { create(:event, is_public: true, name: "Parent Organization") }
    let!(:transparent_sub) do
      create(:event, parent:, is_public: true, name: "Transparent Sub-organization", slug: "transparent-sub-organization")
    end

    it "renders the rows one level under the expanded organization", :aggregate_failures do
      create(:event, parent: transparent_sub, is_public: true, name: "Transparent Grandchild")

      get(:async_sub_organization_rows, params: { event_id: transparent_sub.slug, guides: "1" })

      expect(table_row_names(response.body)).to eq(["Transparent Grandchild"])
      expect(response.body).to include('data-depth="1"')
    end

    it "omits private sub-organizations from a signed out visitor" do
      create(:event, parent: transparent_sub, is_public: true, name: "Transparent Grandchild")
      create(:event, parent: transparent_sub, is_public: false, name: "Private Grandchild")

      get(:async_sub_organization_rows, params: { event_id: transparent_sub.slug, guides: "1" })

      expect(table_row_names(response.body)).to eq(["Transparent Grandchild"])
    end

    # Get this wrong and a branch appears to continue past its last row.
    it "carries the tree's connecting lines down into the expanded level", :aggregate_failures do
      create(:event, parent: transparent_sub, is_public: true, name: "First Grandchild")
      create(:event, parent: transparent_sub, is_public: true, name: "Second Grandchild")

      get(:async_sub_organization_rows, params: { event_id: transparent_sub.slug, guides: "10" })

      rows = table_rows(response.body)

      expect(rows.map { |row| row["data-depth"] }).to eq(["2", "2"])
      # "10": one level still carrying a line, one whose branch has ended.
      expect(rows.first.css(".sub-organization-row__guide").map { |guide| guide["class"].split.last })
        .to eq(["sub-organization-row__guide--line", "sub-organization-row__guide--connector"])
      # Only the final row closes the branch off.
      expect(rows.map { |row| row["class"].include?("sub-organization-row--last") }).to eq([false, true])
    end

    it "ignores a guides value that isn't a run of flags" do
      create(:event, parent: transparent_sub, is_public: true, name: "Transparent Grandchild")

      get(:async_sub_organization_rows, params: { event_id: transparent_sub.slug, guides: "../nonsense" })

      expect(response.body).to include('data-depth="0"')
    end

    # Authorizing the organization being expanded is what stops the table from
    # being walked by hand into a branch the viewer cannot see.
    it "refuses to expand a private organization for a signed out visitor" do
      private_sub = create(:event, parent:, is_public: false, name: "Private Sub-organization")
      create(:event, parent: private_sub, is_public: true, name: "Transparent Grandchild")

      get(:async_sub_organization_rows, params: { event_id: private_sub.slug, guides: "1" })

      expect(response).to have_http_status(:redirect)
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

  describe "#async_sub_organization_balances" do
    let(:parent) { create(:event, is_public: true) }
    let!(:transparent_sub) { create(:event, :with_positive_balance, parent:, is_public: true) }
    let!(:private_sub) { create(:event, :with_positive_balance, parent:, is_public: false) }

    it "returns a balance for each requested descendant" do
      grandchild = create(:event, :with_positive_balance, parent: transparent_sub, is_public: true)

      get(:async_sub_organization_balances,
          params: { event_id: parent.slug, ids: [transparent_sub.public_id, grandchild.public_id] },
          format: :json)

      expect(response.parsed_body).to eq(
        transparent_sub.public_id => money(transparent_sub.ledger.available_balance_cents),
        grandchild.public_id      => money(grandchild.ledger.available_balance_cents)
      )
    end

    it "skips a private descendant for a signed out visitor" do
      get(:async_sub_organization_balances,
          params: { event_id: parent.slug, ids: [transparent_sub.public_id, private_sub.public_id] },
          format: :json)

      expect(response.parsed_body.keys).to eq([transparent_sub.public_id])
    end

    it "returns a private descendant for an organizer of the parent" do
      sign_in_organizer_of(parent)

      get(:async_sub_organization_balances,
          params: { event_id: parent.slug, ids: [private_sub.public_id] },
          format: :json)

      expect(response.parsed_body.keys).to eq([private_sub.public_id])
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
