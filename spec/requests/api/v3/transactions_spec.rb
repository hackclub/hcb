# frozen_string_literal: true

require "rails_helper"

# The v3 API had no coverage before the ledger rewrite. The assertion that
# matters most is parity: without the header the legacy transaction engines run,
# with it Ledger::Query does, and the payloads must agree.
RSpec.describe "Api::V3 transactions", type: :request do
  let(:event) { create(:event, is_public: true) }
  let(:ledger_header) { { Api::Models::LedgerTransaction::HEADER => Api::Models::LedgerTransaction::LEDGER } }

  # One fixture visible to both engines: the canonical event mapping is what the
  # legacy engines read, and CanonicalTransaction#assign_ledger_item builds the
  # Ledger::Item. Ledger::Mapper derives the ledger from raw transaction sources
  # (Column, Stripe, linked objects), which a plaid-backed fixture has none of,
  # so map it explicitly the way Ledger::Query's own spec does.
  #
  # `date` is today so the CT's date and the ledger item's datetime agree —
  # in production `backfill_ledger_item_datetime_task` aligns them.
  def create_transaction(amount_cents: -1234, memo: "Test transaction")
    ct = create(:canonical_transaction, amount_cents:, memo:, date: Date.current)
    create(:canonical_event_mapping, event:, canonical_transaction: ct)
    hcb_code = ct.reload.local_hcb_code

    Ledger::Mapping.create!(ledger: event.ledger, ledger_item: hcb_code.ledger_item, on_primary_ledger: true)

    hcb_code
  end

  def get_transactions(headers: {})
    get "/api/v3/organizations/#{event.slug}/transactions", params: { expand: "transaction" }, headers: headers
    response
  end

  def by_id(body) = body.index_by { |txn| txn["id"] }

  before { create_transaction }

  describe "GET /organizations/:id/transactions" do
    it "returns the same payload from both engines" do
      legacy = by_id(get_transactions.parsed_body)
      ledger = by_id(get_transactions(headers: ledger_header).parsed_body)

      expect(ledger.keys).to match_array(legacy.keys)
      expect(ledger).to eq(legacy)
    end

    it "returns the same pagination headers from both engines" do
      headers = ->(res) { res.headers.slice("X-Total", "X-Total-Pages", "X-Per-Page", "X-Page") }

      legacy = headers.call(get_transactions)

      expect(headers.call(get_transactions(headers: ledger_header))).to eq(legacy)
      expect(legacy["X-Total"].to_i).to eq(1)
    end

    it "exposes the ledger item's public id alongside the HcbCode-derived id" do
      txn = get_transactions(headers: ledger_header).parsed_body.first
      item = Ledger::Item.find_by_public_id(txn["ledger_item_id"])

      expect(txn["id"]).to start_with("txn_")
      expect(txn["ledger_item_id"]).to start_with("lit_")
      expect(item.hcb_code.public_id).to eq(txn["id"])
    end

    it "runs Ledger::Query instead of the legacy engines when the header is sent" do
      expect(TransactionGroupingEngine::Transaction::All).not_to receive(:new)
      expect(PendingTransactionEngine::PendingTransaction::All).not_to receive(:new)

      expect(get_transactions(headers: ledger_header)).to have_http_status(:ok)
    end

    it "does not run Ledger::Query without the header" do
      expect(Ledger::Query).not_to receive(:new)

      expect(get_transactions).to have_http_status(:ok)
    end

    it "ignores an unrecognised header value" do
      expect(Ledger::Query).not_to receive(:new)

      expect(get_transactions(headers: { Api::Models::LedgerTransaction::HEADER => "hcb_code" })).to have_http_status(:ok)
    end
  end

  describe "GET /transactions/:id" do
    it "returns the same payload from both engines" do
      id = get_transactions.parsed_body.first["id"]

      get "/api/v3/transactions/#{id}", params: { expand: "transaction" }
      legacy = response.parsed_body

      get "/api/v3/transactions/#{id}", params: { expand: "transaction" }, headers: ledger_header

      expect(response.parsed_body).to eq(legacy)
    end

    it "404s on the ledger engine for a transaction with no event" do
      hcb_code = create(:hcb_code)

      get "/api/v3/transactions/#{hcb_code.public_id}", headers: ledger_header

      expect(response).to have_http_status(:not_found)
    end
  end
end
