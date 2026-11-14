# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transaction exports", type: :request do
  let(:event) { create(:event, is_public: true) }
  let(:last_month) { Date.today.prev_month.beginning_of_month.to_s }

  describe "GET /exports/:event with no extension" do
    it "serves CSV to a client that accepts anything, as curl does" do
      get "/exports/#{event.slug}", headers: { "Accept" => "*/*" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
    end

    it "serves the format the Accept header asks for" do
      get "/exports/#{event.slug}", headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
    end
  end

  describe "GET /exports/collect_email" do
    it "sends a request with nothing to export back to the homepage" do
      get "/exports/collect_email"

      expect(response).to redirect_to(root_path)
    end

    it "sends the filters back with the address, as form fields" do
      get "/exports/collect_email", params: { file_extension: "csv", event_slug: event.slug, source: "ledger", q: "Coffee" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("action=\"/exports/ledger/#{event.slug}.csv\"")
      expect(response.body).to match(/<input [^>]*type="hidden"[^>]*name="q"[^>]*>/)
      expect(response.body).to match(/<input [^>]*name="q"[^>]*value="Coffee"[^>]*>|<input [^>]*value="Coffee"[^>]*name="q"[^>]*>/)
    end

    it "sends nothing extra back for a legacy export" do
      get "/exports/collect_email", params: { file_extension: "csv", event_slug: event.slug, source: "transactions" }

      expect(response.body).to include("action=\"/exports/#{event.slug}.csv\"")
      expect(response.body).not_to include("name=\"q\"")
    end
  end

  describe "GET /exports/:event.pdf" do
    it "renders the statement for a valid month" do
      get "/exports/#{event.slug}.pdf", params: { start_date: last_month }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
    end

    it "returns a 400 instead of raising on an unparseable start_date" do
      get "/exports/#{event.slug}.pdf", params: { start_date: "not-a-date" }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq("Invalid date.")
    end

    it "returns a 400 instead of raising on an unparseable end_date" do
      get "/exports/#{event.slug}.pdf", params: { start_date: last_month, end_date: "not-a-date" }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq("Invalid date.")
    end

    it "returns a 400 for a month that has not ended yet" do
      get "/exports/#{event.slug}.pdf", params: { start_date: Date.today.beginning_of_month.to_s }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq("Can not create a financial statement for #{Date.today.strftime("%B %Y")}.")
    end

    it "returns a 400 when the end date is before the start date" do
      get "/exports/#{event.slug}.pdf", params: { start_date: last_month, end_date: Date.today.prev_month(3).to_s }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq("End date cannot be before the start date.")
    end
  end

  describe "GET /exports/:event.csv" do
    describe "when the export is too large and must be emailed" do
      let(:organizer) { create(:user) }
      let(:private_event) { create(:event, is_public: false, organizers: [organizer]) }
      let(:attacker_email) { "attacker@evil.test" }

      def sign_in_with(session)
        allow_any_instance_of(SessionsHelper)
          .to receive(:find_current_session)
          .and_return(session)
      end

      before do
        allow_any_instance_of(Export::Event::Transactions::Csv).to receive(:async?).and_return(true)
      end

      it "emails a signed-in user's export to them and ignores the email param" do
        sign_in_with(create(:user_session, user: organizer, expiration_at: 1.hour.from_now))

        expect do
          get "/exports/#{private_event.slug}.csv", params: { email: attacker_email }
        end.to have_enqueued_job(ExportJob)

        expect(response).to redirect_to(event_path(private_event))

        export = Export.last
        expect(export.requested_by).to eq(organizer)
        expect(export.public_only).to be(false)
        expect(User.find_by(email: attacker_email)).to be_nil
      end

      it "does not export a private org for a signed-out requester, even with an email" do
        get "/exports/#{private_event.slug}.csv", params: { email: attacker_email }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to start_with(auth_users_url)
        expect(Export.count).to eq(0)
        expect(User.find_by(email: attacker_email)).to be_nil
      end

      it "still lets a signed-out requester email themselves a public org's export" do
        expect do
          get "/exports/#{event.slug}.csv", params: { email: "someone@example.com" }
        end.to have_enqueued_job(ExportJob)

        export = Export.last
        expect(export.requested_by.email).to eq("someone@example.com")
        expect(export.public_only).to be(true)
      end

      it "sends a signed-out requester to the email form when no email is given" do
        get "/exports/#{event.slug}.csv"

        expect(response).to redirect_to(collect_email_exports_path(file_extension: "csv", event_slug: event.slug, source: "transactions"))
        expect(Export.count).to eq(0)
      end
    end

    it "serves the CSV for a valid month" do
      get "/exports/#{event.slug}.csv", params: { start_date: last_month }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
    end

    it "returns a 400 instead of raising on an unparseable start_date" do
      get "/exports/#{event.slug}.csv", params: { start_date: "not-a-date" }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq("Invalid date.")
    end
  end
end
