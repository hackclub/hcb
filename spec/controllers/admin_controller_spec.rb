# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminController do
  include SessionSupport

  describe "#disbursement_process" do
    render_views

    it "renders mission statements for the source and destination events" do
      admin = create(:user, :make_admin)
      source_event = create(:event, description: "Source mission statement")
      destination_event = create(:event, description: "Destination mission statement")
      disbursement = create(:disbursement, source_event:, event: destination_event)

      create_session(admin, verified: true)

      get :disbursement_process, params: { id: disbursement.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Source mission statement")
      expect(response.body).to include("Destination mission statement")
    end
  end

  describe "#ledger_item_process" do
    render_views

    it "renders the item, its current mapping and the mapper's suggestion" do
      admin = create(:user, :make_admin)
      event = create(:event, name: "Ledger item process spec event")
      # refresh! recomputes `memo` from the item's transactions, so the
      # searched-for text has to be a custom memo to survive being mapped.
      ledger_item = create(:ledger_item, custom_memo: "A transaction worth mapping")
      Ledger::Mapping.map_primary!(ledger: event.ledger, ledger_item:, mapped_by: admin)

      create_session(admin, verified: true)

      get :ledger_item_process, params: { id: ledger_item.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("A transaction worth mapping")
      expect(response.body).to include("Ledger item process spec event")
      expect(response.body).to include("What the mapper would do")
    end

    it "renders a card grant mapping, its history and its transactions" do
      admin = create(:user, :make_admin)
      create(:governance_admin_transfer_limit, user: admin)
      card_grant = create(:card_grant, sent_by: admin)
      canonical_transaction = create(:canonical_transaction, memo: "CARD GRANT SPEND")
      ledger_item = canonical_transaction.ledger_item
      Ledger::Mapping.map_primary!(ledger: card_grant.ledger, ledger_item:, mapped_by: admin)
      Ledger::Mapping.map_non_primary!(ledger: create(:ledger), ledger_item:, mapped_by: admin)

      create_session(admin, verified: true)

      get :ledger_item_process, params: { id: ledger_item.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("#{card_grant.email}&#39;s card grant")
      expect(response.body).to include("CARD GRANT SPEND")
      expect(response.body).to include("Mapping history")
      expect(response.body).to include("Other ledgers")
    end

    it "renders an item's pending transactions" do
      admin = create(:user, :make_admin)
      canonical_pending_transaction = create(:canonical_pending_transaction, memo: "STILL IN FLIGHT")

      create_session(admin, verified: true)

      get :ledger_item_process, params: { id: canonical_pending_transaction.ledger_item.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("STILL IN FLIGHT")
    end

    it "renders an unmapped item" do
      admin = create(:user, :make_admin)
      ledger_item = create(:ledger_item, custom_memo: "Nobody's transaction")

      create_session(admin, verified: true)

      get :ledger_item_process, params: { id: ledger_item.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Unmapped")
    end
  end

  describe "#ledger_item_set_ledger" do
    it "maps the item to an event's primary ledger" do
      admin = create(:user, :make_admin)
      event = create(:event)
      ledger_item = create(:ledger_item)

      create_session(admin, verified: true)

      post :ledger_item_set_ledger, params: { id: ledger_item.id, target: "event", event_id: event.id }

      expect(response).to redirect_to(ledger_item_process_admin_path(ledger_item))
      expect(ledger_item.reload.primary_ledger).to eq(event.ledger)
      expect(ledger_item.primary_mapping.mapped_by).to eq(admin)
    end

    it "maps the item to a card grant's primary ledger" do
      admin = create(:user, :make_admin)
      create(:governance_admin_transfer_limit, user: admin)
      # An admin-sent grant skips the source event's balance check.
      card_grant = create(:card_grant, sent_by: admin)
      ledger_item = create(:ledger_item)

      create_session(admin, verified: true)

      post :ledger_item_set_ledger, params: { id: ledger_item.id, target: "card_grant", card_grant_id: card_grant.id }

      expect(ledger_item.reload.primary_ledger).to eq(card_grant.ledger)
    end

    it "unmaps the item" do
      admin = create(:user, :make_admin)
      event = create(:event)
      ledger_item = create(:ledger_item)
      Ledger::Mapping.map_primary!(ledger: event.ledger, ledger_item:, mapped_by: admin)

      create_session(admin, verified: true)

      post :ledger_item_set_ledger, params: { id: ledger_item.id, target: "unmap" }

      expect(ledger_item.reload.primary_ledger).to be_nil
    end

    it "flashes an error when unmapping an already unmapped item" do
      admin = create(:user, :make_admin)
      ledger_item = create(:ledger_item)

      create_session(admin, verified: true)

      post :ledger_item_set_ledger, params: { id: ledger_item.id, target: "unmap" }

      expect(flash[:error]).to eq("This ledger item isn't mapped to a primary ledger.")
    end
  end

  describe "#ledger_item_run_mapper" do
    it "reports back when the mapper can't work out a ledger" do
      admin = create(:user, :make_admin)
      ledger_item = create(:ledger_item)

      create_session(admin, verified: true)

      post :ledger_item_run_mapper, params: { id: ledger_item.id }

      expect(flash[:error]).to eq("The mapper couldn't work out a ledger for this item.")
      expect(ledger_item.reload.primary_ledger).to be_nil
    end
  end

  describe "#ledger_item_refresh" do
    it "recomputes the item's cached columns" do
      admin = create(:user, :make_admin)
      ledger_item = create(:ledger_item)
      ledger_item.update_columns(ct_count: 99)

      create_session(admin, verified: true)

      post :ledger_item_refresh, params: { id: ledger_item.id }

      expect(response).to redirect_to(ledger_item_process_admin_path(ledger_item))
      expect(ledger_item.reload.ct_count).to eq(0)
    end
  end

  describe "#ledger_items" do
    render_views

    it "links each item to its process page" do
      admin = create(:user, :make_admin)
      ledger_item = create(:ledger_item)

      create_session(admin, verified: true)

      get :ledger_items

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ledger_item_process_admin_path(ledger_item))
    end
  end

  describe "#card_grant_search" do
    render_views

    it "returns matching card grants as combobox options" do
      admin = create(:user, :make_admin)
      create(:governance_admin_transfer_limit, user: admin)
      card_grant = create(:card_grant, sent_by: admin)

      create_session(admin, verified: true)

      get :card_grant_search, params: { q: card_grant.email }, format: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(card_grant.email)
    end
  end

  describe "#ledger_item_update_memo" do
    it "sets and clears the custom memo" do
      admin = create(:user, :make_admin)
      ledger_item = create(:ledger_item)

      create_session(admin, verified: true)

      post :ledger_item_update_memo, params: { id: ledger_item.id, custom_memo: "Renamed by ops" }
      expect(ledger_item.reload.custom_memo).to eq("Renamed by ops")

      post :ledger_item_update_memo, params: { id: ledger_item.id, custom_memo: "" }
      expect(ledger_item.reload.custom_memo).to be_nil
    end
  end

  describe "#set_wise_transfer" do
    it "maps the canonical transaction's ledger item onto the transfer's event ledger" do
      admin = create(:user, :make_admin)
      event = create(:event)
      wise_transfer = WiseTransfer.create!(
        event:,
        user: admin,
        aasm_state: "sent",
        amount_cents: 100_00,
        currency: "GBP",
        recipient_country: "GB",
        recipient_name: "Fiona Hackworth",
        recipient_email: "fiona@example.com",
        payment_for: "Speaker fee",
        # Both are required once the transfer has been sent.
        wise_id: "1234567",
        wise_recipient_id: "0199a1f0-7c3a-4a0b-9b2e-6d1f8a3c5e47",
        # Set so the after_create hook skips generate_quote!, which would
        # otherwise reach for a live exchange rate.
        quoted_usd_amount_cents: 130_00,
        usd_amount_cents: 130_00
      )
      canonical_transaction = create(:canonical_transaction, amount_cents: -130_00)

      create_session(admin, verified: true)

      post :set_wise_transfer, params: { id: canonical_transaction.id, wise_transfer_id: wise_transfer.id }

      expect(wise_transfer.reload).to be_deposited
      expect(canonical_transaction.reload.event).to eq(event)
      expect(canonical_transaction.ledger_item.primary_ledger).to eq(event.ledger)
      expect(canonical_transaction.ledger_item.primary_mapping.mapped_by).to eq(admin)
    end
  end

  describe "#ach_start_approval" do
    render_views

    it "renders the ach transfer event's mission statement" do
      admin = create(:user, :make_admin)
      event = create(:event, :with_positive_balance, description: "Money wiring mission statement")
      ach_transfer = create(:ach_transfer, event:)

      create_session(admin, verified: true)

      get :ach_start_approval, params: { id: ach_transfer.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Money wiring mission statement")
    end
  end

  describe "#event_search" do
    it "returns JSON options the combobox can render" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)
      event = create(:event, name: "Hack Club HQ")

      get(:event_search, params: { q: "Hack Club HQ" }, format: :json)

      expect(response).to have_http_status(:ok)
      option = JSON.parse(response.body).find { |o| o["value"] == event.id.to_s }
      expect(option).to include("value" => event.id.to_s, "sublabel" => event.slug)
    end

    # The dropdown labels have to match what `combobox_tag` renders for the
    # preselected value, or re-picking the same org silently changes the text.
    it "labels options with the admin display for an admin" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)
      event = create(:event, name: "Hack Club HQ")

      get(:event_search, params: { q: "Hack Club HQ" }, format: :json)

      labels = JSON.parse(response.body).map { |o| o["label"] }
      expect(labels).to include("Hack Club HQ (ID: #{event.id})")
    end

    it "labels options with the plain name for a non-admin auditor" do
      auditor = create(:user, :make_auditor)
      create_session(auditor, verified: true)
      create(:event, name: "Hack Club HQ")

      get(:event_search, params: { q: "Hack Club HQ" }, format: :json)

      expect(JSON.parse(response.body).map { |o| o["label"] }).to include("Hack Club HQ")
    end

    it "paginates results without overlap across pages" do
      stub_const("ComboboxSearchable::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      3.times { |i| create(:event, name: "ysws #{i}") }

      get(:event_search, params: { q: "ysws", page: 1 }, format: :json)
      page1 = JSON.parse(response.body).map { |o| o["value"] }
      get(:event_search, params: { q: "ysws", page: 2 }, format: :json)
      page2 = JSON.parse(response.body).map { |o| o["value"] }

      expect(page1.size).to eq(2)
      expect(page2.size).to eq(1)
      expect(page1 & page2).to be_empty
    end

    it "clamps non-positive page numbers to the first page" do
      stub_const("ComboboxSearchable::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      3.times { |i| create(:event, name: "ysws #{i}") }

      get(:event_search, params: { q: "ysws", page: 0 }, format: :json)

      expect(JSON.parse(response.body).size).to eq(2)
    end
  end

  describe "#user_search" do
    # The admin label spells out the email and ID, so repeating them in the
    # sublabel wrapped every row to several lines.
    it "gives an admin the detailed label and no redundant sublabel" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)
      user = create(:user, full_name: "Jane Doe")

      get(:user_search, params: { q: "Jane Doe" }, format: :json)

      expect(response).to have_http_status(:ok)
      option = JSON.parse(response.body).find { |o| o["value"] == user.id.to_s }
      expect(option["label"]).to eq("Jane Doe (Email: #{user.email}, ID: #{user.id})")
      expect(option["sublabel"]).to be_nil
    end

    it "gives a non-admin auditor the plain name with the email as a sublabel" do
      auditor = create(:user, :make_auditor)
      create_session(auditor, verified: true)
      user = create(:user, full_name: "Jane Doe")

      get(:user_search, params: { q: "Jane Doe" }, format: :json)

      option = JSON.parse(response.body).find { |o| o["value"] == user.id.to_s }
      expect(option["label"]).to eq("Jane Doe")
      expect(option["sublabel"]).to eq(user.email)
    end

    it "paginates results without overlap across pages" do
      stub_const("ComboboxSearchable::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      ["Searchable Personone", "Searchable Persontwo", "Searchable Personthree"].each do |name|
        create(:user, full_name: name)
      end

      get(:user_search, params: { q: "Searchable", page: 1 }, format: :json)
      page1 = JSON.parse(response.body).map { |o| o["value"] }
      get(:user_search, params: { q: "Searchable", page: 2 }, format: :json)
      page2 = JSON.parse(response.body).map { |o| o["value"] }

      expect(page1.size).to eq(2)
      expect(page1 & page2).to be_empty
    end
  end
end
