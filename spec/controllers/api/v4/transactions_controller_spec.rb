# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::TransactionsController do
  render_views

  let(:user) { create(:user) }
  let(:event) { create(:event) }

  before do
    create(:organizer_position, user:, event:)
    request.headers["Authorization"] = "Bearer #{create(:api_token, user:).token}"
  end

  def create_transaction(amount_cents: -1234, memo: "Test transaction")
    ct = create(:canonical_transaction, amount_cents:, memo:, date: Date.current)
    create(:canonical_event_mapping, event:, canonical_transaction: ct)
    hcb_code = ct.reload.local_hcb_code

    Ledger::Mapping.map_primary!(ledger: event.ledger, ledger_item: hcb_code.ledger_item, mapped_by: Ledger::Mapper::SYSTEM)

    hcb_code
  end

  # Keys and value types only; values may legitimately differ between engines.
  def shape(node)
    case node
    when Hash then node.transform_values { |value| shape(value) }
    when Array then node.map { |value| shape(value) }
    when true, false then :boolean
    else node.class.name
    end
  end

  def with_engine(enabled)
    enabled ? Flipper.enable(described_class::LEDGER_ENGINE_FLAG, user) : Flipper.disable(described_class::LEDGER_ENGINE_FLAG)
    yield
    response.parsed_body
  end

  describe "#index" do
    before { create_transaction }

    it "returns the same structure from both engines, plus ledger_item_id" do
      legacy = with_engine(false) { get :index, params: { id: event.public_id }, format: :json }
      ledger = with_engine(true) { get :index, params: { id: event.public_id }, format: :json }

      expect(ledger.except("data")).to eq(legacy.except("data"))
      expect(legacy["data"].first["ledger_item_id"]).to be_nil
      expect(Ledger::Item.find_by_public_id(ledger["data"].first["ledger_item_id"])).to be_present

      legacy_shape = shape(legacy["data"].first).except("ledger_item_id")
      ledger_shape = shape(ledger["data"].first).except("ledger_item_id")
      expect(ledger_shape).to eq(legacy_shape)
      expect(ledger["data"].map { |tx| tx["id"] }).to eq(legacy["data"].map { |tx| tx["id"] })
    end

    it "paginates the ledger engine with HcbCode cursors" do
      2.times { |i| create_transaction(memo: "Another #{i}") }
      Flipper.enable(described_class::LEDGER_ENGINE_FLAG, user)

      get :index, params: { id: event.public_id }, format: :json
      all_ids = response.parsed_body["data"].map { |tx| tx["id"] }
      expect(all_ids.size).to eq(3)

      paged_ids = []
      after = nil
      loop do
        get :index, params: { id: event.public_id, limit: 1, after: }.compact, format: :json
        body = response.parsed_body
        expect(body["total_count"]).to eq(3)
        paged_ids << body["data"].sole["id"]
        break unless body["has_more"]

        after = paged_ids.last
      end

      expect(paged_ids).to eq(all_ids)
    end
  end

  describe "#show" do
    it "returns the same structure from both engines, plus ledger_item_id" do
      hcb_code = create_transaction

      legacy = with_engine(false) { get :show, params: { id: hcb_code.public_id }, format: :json }
      ledger = with_engine(true) { get :show, params: { id: hcb_code.public_id }, format: :json }

      expect(legacy).to have_key("ledger_item_id")
      expect(legacy["ledger_item_id"]).to be_nil
      expect(ledger["ledger_item_id"]).to eq(hcb_code.ledger_item.public_id)
      expect(shape(ledger).except("ledger_item_id")).to eq(shape(legacy).except("ledger_item_id"))
    end
  end
end
