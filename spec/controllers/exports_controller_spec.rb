# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExportsController, type: :controller do
  include SessionSupport

  let(:event) { create(:event) }
  let(:ledger) { event.ledger }
  let(:organizer) { create(:user) }

  # Ledger items recompute themselves from their canonical transactions, which
  # these don't have, so pin the values under test (and a ct_count, without which
  # the query treats the item as empty and skips it).
  def mapped_item(**attrs)
    item = create(:ledger_item, **attrs)
    Ledger::Mapping.create!(ledger:, ledger_item: item, on_primary_ledger: true)
    item.update_columns(ct_count: 1, **attrs)
    item
  end

  describe "GET #ledger" do
    before do
      create(:organizer_position, user: organizer, event:)
      create_session(organizer, verified: true)

      mapped_item(amount_cents: -500, memo: "Coffee", datetime: Date.new(2024, 3, 1))
      mapped_item(amount_cents: 2_000, memo: "Donation from Fiona", datetime: Date.new(2024, 1, 15))
    end

    it "exports the whole ledger when nothing is filtered" do
      get :ledger, params: { event: event.slug }, format: :csv

      expect(response).to be_successful
      expect(response.body).to include("Coffee", "Donation from Fiona")
      expect(response.headers["Content-disposition"]).to include("#{event.slug}_transactions_")
    end

    it "exports only what the filters match" do
      get :ledger, params: { event: event.slug, direction: "expenses" }, format: :csv

      expect(response.body).to include("Coffee")
      expect(response.body).not_to include("Donation from Fiona")
    end

    it "names a filtered export as such" do
      get :ledger, params: { event: event.slug, direction: "expenses" }, format: :csv

      expect(response.headers["Content-disposition"]).to include("#{event.slug}_filtered_transactions_")
    end

    it "respects the search box" do
      get :ledger, params: { event: event.slug, q: "Coffee" }, format: :csv

      expect(response.body).to include("Coffee")
      expect(response.body).not_to include("Donation from Fiona")
    end

    it "serves JSON" do
      get :ledger, params: { event: event.slug, direction: "revenue" }, format: :json

      expect(JSON.parse(response.body).map { |row| row["memo"] }).to eq(["Donation from Fiona"])
    end

    it "serves a ledger journal" do
      get :ledger, params: { event: event.slug }, format: :ledger

      expect(response.headers["Content-Type"]).to eq("text/ledger")
    end

    context "when signed out" do
      before { cookies.delete(:session_token) }

      it "refuses to filter a public organization's ledger" do
        event.update!(is_public: true)

        get :ledger, params: { event: event.slug, direction: "expenses" }, format: :csv

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
