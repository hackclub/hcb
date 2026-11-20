# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transaction exports", type: :request do
  let(:event) { create(:event, is_public: true) }
  let(:last_month) { Date.today.prev_month.beginning_of_month.to_s }

  describe "emailed downloads" do
    include ActionMailer::TestHelper

    it "stores the export and emails an HCB download link instead of an attachment" do
      freeze_time

      user = create(:user)
      export = Export::Event::Transactions::Csv.create!(requested_by: user, event_id: event.id, public_only: true)
      content = export.content
      filename = export.filename

      emails = capture_emails do
        ExportJob.perform_now(export_id: export.id)
      end

      file = export.reload.file
      expect(file.download).to eq(content)
      expect(file.filename.to_s).to eq(filename)
      expect(file.content_type).to eq("text/csv")

      email = emails.sole
      expect(email.to).to eq([user.email])
      expect(email.attachments).to be_empty
      body = Nokogiri::HTML(email.html_part.body.decoded)
      expect(body.text).to include(export.label)
      link = body.at_css("a:contains('Download your export')")["href"]
      expect(URI.parse(link).host).to eq(URI.parse(root_url).host)
      expect(link).to eq(download_export_url(export.signed_id(purpose: :download)))

      get link
      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(content)
      expect(response.headers["Content-Disposition"]).to include("attachment", filename)
    end
  end

  describe "GET /exports/:id/download" do
    let(:requester) { create(:user) }
    let(:export) { Export::Event::Transactions::Csv.create!(requested_by: requester, event_id: event.id, public_only: false) }
    let(:download_path) { download_export_path(export.signed_id(purpose: :download)) }

    before do
      export.file.attach(io: StringIO.new("private export contents"), filename: "transactions.csv", content_type: "text/csv")
    end

    it "requires login even when the organization is public" do
      get download_path

      expect(response.location).to start_with(auth_users_url)
      expect(Rack::Utils.parse_query(URI.parse(response.location).query)["return_to"]).to eq(download_export_url(export.signed_id(purpose: :download)))
    end

    it "does not let another signed-in user download the export" do
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session)
        .and_return(create(:user_session, user: create(:user), expiration_at: 1.hour.from_now))

      get download_path

      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "lets the requester download a private organization's export" do
      export.update!(event_id: create(:event, is_public: false).id)
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session)
        .and_return(create(:user_session, user: requester, expiration_at: 1.hour.from_now))

      get download_path

      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("private export contents")
      expect(response.headers["Content-Disposition"]).to include("attachment", "transactions.csv")
    end

    it "requires login for reports without a public_only parameter" do
      export = Export::Event::Balances.create!(requested_by: requester)
      export.file.attach(io: StringIO.new("private balances"), filename: "balances.csv", content_type: "text/csv")

      get download_export_path(export.signed_id(purpose: :download))

      expect(response.location).to start_with(auth_users_url)
    end

    it "rejects an invalid download token" do
      get download_export_path("invalid")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /exports/:event.pdf" do
    before { allow(CloudflareBrowserRun).to receive(:pdf).and_return("%PDF-1.4") }

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

        expect(response).to redirect_to(collect_email_exports_path(file_extension: "csv", event_slug: event.slug))
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
