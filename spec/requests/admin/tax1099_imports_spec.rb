# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Tax1099Imports", type: :request do
  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  let(:admin) { create(:user, :make_admin) }

  before do
    admin_session = create(:user_session, user: admin, verified: true, expiration_at: 1.hour.from_now)

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(admin_session)

    allow(TaxbanditsService).to receive(:create_from_data).and_return({ "SubmissionId" => "sub-1" })
    allow(Tax::IdentificationNumber::Hasher).to receive(:kms_key_id).and_return(nil)
  end

  let(:pdf) do
    Rack::Test::UploadedFile.new(
      StringIO.new("%PDF-1.4\nsigned W-9\n%%EOF"), "application/pdf", original_filename: "w9.pdf"
    )
  end

  let(:row) do
    {
      first_name: "Ada", middle_name: "", last_name: "Lovelace", suffix: "",
      tin: "123-45-6789", tin_type: "SSN", federal_tax_classification: "Individual",
      address1: "8 Fake St", city: "Shelburne", state: "VT", zip_code: "05482",
      email: "ada@example.com"
    }
  end

  def json = response.parsed_body

  describe "GET /admin/tax1099_imports/new" do
    it "renders the import page" do
      get "/admin/tax1099_imports/new"

      expect(response).to have_http_status(:ok)
    end

    # The whole point of the page: the CSV is read in the browser, so the page
    # must ship the classification list rather than ask the server per row.
    it "ships the classification options to the browser" do
      get "/admin/tax1099_imports/new"

      Tax1099ImportService::FEDERAL_TAX_CLASSIFICATIONS.each do |classification|
        expect(response.body).to include(classification)
      end
    end

    # The Stimulus controller reads and writes each row's fields by this list,
    # so a field with no matching input would silently submit blank.
    it "renders an input for every field the import takes" do
      get "/admin/tax1099_imports/new"

      keys = Tax1099ImportService::FIELDS.map { _1[:key] }

      expect(response.body).to include(%(data-tax1099-import-fields-value="#{keys.to_json.gsub(%("), "&quot;")}"))
      keys.each { expect(response.body).to include(%(data-field="#{_1}")) }
    end
  end

  describe "POST /admin/tax1099_imports" do
    it "imports the row and reports the form it created" do
      post "/admin/tax1099_imports", params: row.merge(pdf:)

      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("imported")
      expect(json["needs_manual_review"]).to be(false)
      expect(Tax::Form.find_by_public_id(json["form_id"])).to be_completed
    end

    it "hands TaxBandits a PdfUrl that serves the uploaded PDF exactly once" do
      post "/admin/tax1099_imports", params: row.merge(pdf:)

      payload = nil
      expect(TaxbanditsService).to have_received(:create_from_data) { |sent| payload = sent }

      get URI.parse(payload["PdfUrl"]).request_uri
      expect(response).to have_http_status(:ok)
      expect(response.body.b).to eq("%PDF-1.4\nsigned W-9\n%%EOF".b)

      travel(Tax::W9PdfStore::GRACE_PERIOD + 1.second) do
        get URI.parse(payload["PdfUrl"]).request_uri
        expect(response).to have_http_status(:not_found)
      end
    end

    it "reports a duplicate without creating a second form" do
      post "/admin/tax1099_imports", params: row.merge(pdf:)

      expect {
        post "/admin/tax1099_imports", params: row.merge(pdf:)
      }.not_to change(Tax::Form, :count)

      expect(response).to have_http_status(:conflict)
      expect(json["status"]).to eq("duplicate")
    end

    it "reports an invalid row without contacting TaxBandits" do
      post "/admin/tax1099_imports", params: row.merge(city: "", pdf:)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["status"]).to eq("invalid")
      expect(TaxbanditsService).not_to have_received(:create_from_data)
    end

    it "rejects an upload that isn't a PDF" do
      not_a_pdf = Rack::Test::UploadedFile.new(
        StringIO.new("<html>gotcha</html>"), "application/pdf", original_filename: "w9.pdf"
      )

      post "/admin/tax1099_imports", params: row.merge(pdf: not_a_pdf)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["message"]).to match(/not a PDF/)
    end

    it "keeps the payee's TIN out of a TaxBandits rejection" do
      allow(TaxbanditsService).to receive(:create_from_data)
        .and_raise("422: {\"Errors\":[{\"Message\":\"TIN 123-45-6789 is invalid\"}]}")

      post "/admin/tax1099_imports", params: row.merge(pdf:)

      expect(response).to have_http_status(:bad_gateway)
      expect(json["message"]).not_to include("123-45-6789")
    end

    it "is closed to non-admins" do
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(nil)

      post "/admin/tax1099_imports", params: row.merge(pdf:)

      expect(response).not_to have_http_status(:ok)
      expect(Tax::Form.count).to eq(0)
    end
  end

  describe "GET /admin/tax1099_imports/legal_entities" do
    let(:user) { create(:user, email: "ada@example.com") }

    it "lists the payee's business legal entities for a business row" do
      business = create(:legal_entity, name: "Engines Co", entity_type: :business, users: [user])

      get "/admin/tax1099_imports/legal_entities",
          params: { email: user.email, tin_type: "EIN", federal_tax_classification: "Partnership" }

      expect(json["legal_entities"]).to eq([{ "id" => business.id, "name" => "Engines Co", "entity_type" => "business" }])
    end

    it "asks nothing for a personal row, which always goes on the personal entity" do
      create(:legal_entity, entity_type: :business, users: [user])

      get "/admin/tax1099_imports/legal_entities",
          params: { email: user.email, tin_type: "SSN", federal_tax_classification: "Individual" }

      expect(json["legal_entities"]).to be_empty
    end

    it "is closed to non-admins" do
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(nil)

      get "/admin/tax1099_imports/legal_entities",
          params: { email: user.email, tin_type: "EIN", federal_tax_classification: "Partnership" }

      expect(response).not_to have_http_status(:ok)
    end
  end
end
