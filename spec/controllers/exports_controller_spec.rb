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

    it "doesn't call the export filtered when the filter resolved to nothing" do
      get :ledger, params: { event: event.slug, tag: "nonexistent" }, format: :csv

      expect(response.body).to include("Coffee", "Donation from Fiona")
      expect(response.headers["Content-disposition"]).to include("#{event.slug}_transactions_")
    end

    it "treats a date that doesn't parse as no filter" do
      get :ledger, params: { event: event.slug, start: "2024-02-30" }, format: :csv

      expect(response).to be_successful
      expect(response.body).to include("Coffee", "Donation from Fiona")
      expect(response.headers["Content-disposition"]).to include("#{event.slug}_transactions_")
    end

    it "treats a type nothing is known by as no filter" do
      get :ledger, params: { event: event.slug, type: "bogus" }, format: :csv

      expect(response).to be_successful
      expect(response.body).to include("Coffee", "Donation from Fiona")
      expect(response.headers["Content-disposition"]).to include("#{event.slug}_transactions_")
    end

    it "treats an amount beyond any number as no filter" do
      get :ledger, params: { event: event.slug, minimum_amount: "1e999", maximum_amount: "-1e999" }, format: :csv

      expect(response).to be_successful
      expect(response.body).to include("Coffee", "Donation from Fiona")
    end

    it "treats a filter that isn't even a string as no filter" do
      get :ledger, params: { event: event.slug, start: ["x"], end: { a: "b" }, minimum_amount: ["5"], maximum_amount: { a: "b" }, q: ["Coffee"], merchant: ["m"], user: ["u"], type: ["t"], direction: ["expenses"] }, format: :csv

      expect(response).to be_successful
      expect(response.body).to include("Coffee", "Donation from Fiona")
      expect(response.headers["Content-disposition"]).to include("#{event.slug}_transactions_")
    end

    it "filters by a date range" do
      get :ledger, params: { event: event.slug, start: "2024-02-01", end: "2024-03-31" }, format: :csv

      expect(response.body).to include("Coffee")
      expect(response.body).not_to include("Donation from Fiona")
    end

    it "filters by merchant without resolving the merchant's name" do
      expect_any_instance_of(Event).not_to receive(:merchants)

      get :ledger, params: { event: event.slug, merchant: "abc" }, format: :csv

      expect(response).to be_successful
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

    it "serves a format negotiated from the Accept header, with no path extension" do
      request.headers["Accept"] = "text/csv"

      get :ledger, params: { event: event.slug }

      expect(response).to be_successful
      expect(response.headers["Content-Type"]).to eq("text/csv")
      expect(response.headers["Content-disposition"]).to end_with(".csv")
    end

    it "serves CSV to a client that accepts anything, as curl does" do
      request.headers["Accept"] = "*/*"

      get :ledger, params: { event: event.slug }

      expect(response).to be_successful
      expect(response.headers["Content-Type"]).to eq("text/csv")
      expect(response.headers["Content-disposition"]).to end_with(".csv")
    end

    it "is not found for an organization with no ledger" do
      allow_any_instance_of(Event).to receive(:ledger).and_return(nil)

      expect { get :ledger, params: { event: event.slug }, format: :csv }.to raise_error(ActionController::RoutingError)
    end

    context "when signed in without access to the organization" do
      let(:private_event) { create(:event, is_public: false) }

      before { create_session(create(:user), verified: true) }

      it "refuses before resolving the filters" do
        expect_any_instance_of(Event).not_to receive(:merchants)

        get :ledger, params: { event: private_event.slug, merchant: "abc" }, format: :csv

        expect(response).not_to be_successful
      end
    end

    context "when signed out" do
      before { cookies.delete(:session_token) }

      it "refuses to filter a public organization's ledger" do
        event.update!(is_public: true)

        get :ledger, params: { event: event.slug, direction: "expenses" }, format: :csv

        expect(response).to have_http_status(:bad_request)
      end

      # Signed-out readers can't use the filter menu, but they can search, and
      # a search's results can still be too big to serve inline.
      context "when the search's results are too big to serve inline" do
        before do
          event.update!(is_public: true)
          stub_const("Export::Ledger::Item::Base::ASYNC_THRESHOLD", 0)
        end

        it "carries the search to the email form" do
          get :ledger, params: { event: event.slug, q: "Coffee" }, format: :csv

          expect(response).to redirect_to(collect_email_exports_path(file_extension: "csv", event_slug: event.slug, source: "ledger", q: "Coffee"))
        end

        it "emails the search's results, not the whole ledger" do
          expect do
            get :ledger, params: { event: event.slug, q: "Coffee", email: "fiona@example.com" }, format: :csv
          end.to have_enqueued_job(ExportJob)

          export = Export.last
          expect(export.query.to_s).to include("Coffee")
          expect(export.filtered).to be(true)
          expect(CSV.parse(export.content, headers: true).map { |row| row["memo"] }).to eq(["Coffee"])
        end
      end
    end
  end
end
