# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tax1099ImportService do
  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  let(:pdf_bytes) { "%PDF-1.4\nsigned W-9\n%%EOF" }

  # A fresh handle each time: storing a PDF reads the IO to the end, so a
  # memoized one would come back empty on a second import.
  def pdf = StringIO.new(pdf_bytes)

  let(:pdf_url_builder) { ->(token) { "https://hcb.test/taxbandits/w9_certificate.pdf?token=#{token}" } }

  let(:person_data) do
    {
      first_name: "Ada", middle_name: "", last_name: "Lovelace", suffix: "",
      tin: "123-45-6789", tin_type: "SSN", federal_tax_classification: "Individual",
      address1: "8 Fake St", city: "Shelburne", state: "VT", zip_code: "05482",
      email: "ada@example.com"
    }
  end

  let(:business_data) do
    person_data.merge(
      first_name: "Analytical Engines LLC", last_name: "",
      tin: "12-3456789", tin_type: "EIN", federal_tax_classification: "Partnership",
      email: "ada@example.com"
    )
  end

  def run(data: person_data, legal_entity: nil, file: :default)
    file = pdf if file == :default
    described_class.new(data:, pdf: file, legal_entity:, pdf_url_builder:).run
  end

  before do
    allow(TaxbanditsService).to receive(:create_from_data).and_return({ "SubmissionId" => "sub-1" })

    # Fall back to the keyed dev HMAC so fingerprinting a TIN doesn't reach out
    # to KMS in environments that have a real key configured.
    allow(Tax::IdentificationNumber::Hasher).to receive(:kms_key_id).and_return(nil)
  end

  describe "a personal (SSN) row" do
    it "creates a completed tax1099 W-9 on the payee's personal legal entity" do
      result = run

      expect(result.form).to have_attributes(
        source: "tax1099", external_service: "taxbandits", external_id: "sub-1",
        form_type: "W9", entity_type: "person", aasm_state: "completed"
      )
      expect(result.form.completed_at).to be_present
      expect(result.form.legal_entity).to eq(User.find_by(email: "ada@example.com").personal_legal_entity)
      expect(result).not_to be_needs_manual_review
    end

    it "stores the reviewed address on the form" do
      expect(run.form).to have_attributes(
        address_line1: "8 Fake St", address_city: "Shelburne",
        address_state: "VT", address_postal_code: "05482", address_country: "US"
      )
    end
  end

  describe "the TaxBandits payload" do
    it "hands over a one-time PdfUrl that serves the uploaded PDF" do
      run

      payload = nil
      expect(TaxbanditsService).to have_received(:create_from_data) { |sent| payload = sent }

      token = CGI.parse(URI.parse(payload["PdfUrl"]).query)["token"].first
      expect(Tax::W9PdfStore.claim(token)).to eq(pdf_bytes.b)
    end

    it "sends the reviewed W-9 data under the form's public id" do
      result = run

      expect(TaxbanditsService).to have_received(:create_from_data).with(
        hash_including(
          "FormType" => "W9",
          "PayeeRef" => result.form.public_id,
          "FormW9"   => hash_including(
            "FirstNm" => "Ada", "LastNm" => "Lovelace", "Line1Nm" => "Ada Lovelace",
            "TINType" => "SSN", "TIN" => "123-45-6789",
            "FederalTaxClassification" => "Individual"
          )
        )
      )
    end

    it "leaves no blank gaps in Line1Nm when the middle name and suffix are empty" do
      run(data: person_data.merge(middle_name: "", suffix: ""))

      expect(TaxbanditsService).to have_received(:create_from_data)
        .with(hash_including("FormW9" => hash_including("Line1Nm" => "Ada Lovelace")))
    end
  end

  describe "a business (EIN) row" do
    it "creates a new legal entity named after the business when the payee has none" do
      result = run(data: business_data)

      expect(result.form.entity_type).to eq("business")
      expect(result.legal_entity).to have_attributes(name: "Analytical Engines LLC", entity_type: "business")
    end

    it "files a corporation classification as a corporation" do
      result = run(data: business_data.merge(federal_tax_classification: "S Corporation"))

      expect(result.form.entity_type).to eq("corporation")
    end

    context "when the payee already has business legal entities" do
      let(:user) { create(:user, email: "ada@example.com") }
      let!(:existing) { create(:legal_entity, name: "Engines Co", entity_type: :business, users: [user]) }

      it "leaves the form for manual review when no entity was chosen" do
        result = run(data: business_data)

        expect(result).to be_needs_manual_review
        expect(result.form.legal_entity).to be_nil
        expect(result.form).to be_completed
      end

      it "uses the entity the admin chose" do
        result = run(data: business_data, legal_entity: existing)

        expect(result).not_to be_needs_manual_review
        expect(result.form.legal_entity).to eq(existing)
      end

      it "refuses an entity belonging to somebody else" do
        stranger = create(:legal_entity, entity_type: :business, users: [create(:user)])

        expect { run(data: business_data, legal_entity: stranger) }
          .to raise_error(described_class::ValidationError, /does not belong/)
      end
    end
  end

  describe "duplicate detection" do
    it "refuses a second tax1099 form for the same TIN" do
      first = run.form

      expect { run }.to raise_error(described_class::DuplicateError) { |error|
        expect(error.existing_form).to eq(first)
      }
    end

    it "does not create a form or contact TaxBandits for the duplicate" do
      run
      expect { run rescue nil }.not_to change(Tax::Form, :count)
      expect(TaxbanditsService).to have_received(:create_from_data).once
    end

    it "allows a re-import once the original has been discarded" do
      run.form.update!(aasm_state: "discarded")

      expect { run }.not_to raise_error
    end
  end

  describe "validation" do
    it "rejects a row missing a required field" do
      expect { run(data: person_data.merge(city: "")) }
        .to raise_error(described_class::ValidationError, /City/)
    end

    it "rejects a federal tax classification TaxBandits wouldn't accept" do
      expect { run(data: person_data.merge(federal_tax_classification: "Sole Trader")) }
        .to raise_error(described_class::ValidationError, /classification/)
    end

    it "rejects a row with no PDF" do
      expect { run(file: nil) }.to raise_error(described_class::ValidationError, /PDF/)
    end

    it "does not create a form when the row is invalid" do
      expect { run(data: person_data.merge(city: "")) rescue nil }.not_to change(Tax::Form, :count)
    end
  end

  describe "when TaxBandits rejects the submission" do
    before do
      allow(TaxbanditsService).to receive(:create_from_data)
        .and_raise("422: {\"Errors\":[{\"Message\":\"TIN 123-45-6789 is invalid\"}]}")
    end

    it "keeps the payee's TIN out of the error it raises" do
      expect { run }.to raise_error(described_class::SubmissionError) { |error|
        expect(error.message).not_to include("123-45-6789")
        expect(error.message).not_to include("123456789")
        expect(error.message).to include("[FILTERED]")
        # The original exception's unscrubbed message must not ride along.
        expect(error.cause).to be_nil
      }
    end

    it "leaves no form behind" do
      expect { run rescue nil }.not_to change(Tax::Form, :count)
    end

    it "discards the staged PDF instead of leaving it to sit out its TTL" do
      allow(Tax::W9PdfStore).to receive(:discard).and_call_original

      run rescue nil

      expect(Tax::W9PdfStore).to have_received(:discard)
    end
  end

  describe ".legal_entity_candidates" do
    let(:user) { create(:user, email: "ada@example.com") }

    it "is empty for a personal form, which always goes on the personal entity" do
      create(:legal_entity, entity_type: :business, users: [user])

      expect(described_class.legal_entity_candidates(email: user.email, entity_type: :person)).to be_empty
    end

    it "is empty for an unknown email" do
      expect(described_class.legal_entity_candidates(email: "nobody@example.com", entity_type: :business)).to be_empty
    end

    it "lists the payee's business entities, never their personal one" do
      business = create(:legal_entity, entity_type: :business, users: [user])

      expect(described_class.legal_entity_candidates(email: user.email, entity_type: :business))
        .to contain_exactly(business)
    end
  end
end
