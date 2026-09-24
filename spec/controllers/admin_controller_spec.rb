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
end
