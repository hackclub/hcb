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
      form_type: "W9",
      first_name: "Ada", middle_name: "", last_name: "Lovelace", suffix: "",
      tin: "123-45-6789", tin_type: "SSN", federal_tax_classification: "Individual",
      address1: "8 Fake St", city: "Shelburne", state: "VT", zip_code: "05482", completed_on: "2025-03-07",
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

  let(:w8ben_data) do
    {
      form_type: "W8BEN",
      first_name: "Sommaiya Angrish", middle_name: "", last_name: "", suffix: "",
      tin: "ABCDE1234F", tin_type: "FTIN", federal_tax_classification: "",
      address1: "SKA 809, Shipra Krishna Vista", city: "Ghaziabad", state: "Uttar Pradesh",
      zip_code: "201014", country: "in", completed_on: "2025-07-22",
      signer_name: "Sommaiya Angrish", email: "sommaiya@example.com"
    }
  end

  let(:w8bene_data) do
    w8ben_data.merge(form_type: "W8BENE", first_name: "Krishna Studios Pvt Ltd", ch3_status: "CORPORATION", signer_name: "Ravi Krishna")
  end

  def run(data: person_data, legal_entity: nil, new_legal_entity: false, file: :default)
    file = pdf if file == :default
    described_class.new(data:, pdf: file, legal_entity:, new_legal_entity:, pdf_url_builder:).run
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
      expect(result.form.completed_at.to_date).to eq(Date.new(2025, 3, 7))
      expect(result.form.legal_entity).to eq(User.find_by(email: "ada@example.com").personal_legal_entity)
    end

    it "stores the reviewed address on the form" do
      expect(run.form).to have_attributes(
        address_line1: "8 Fake St", address_city: "Shelburne",
        address_state: "VT", address_postal_code: "05482", address_country: "US"
      )
    end
  end

  it "has already put the form on its legal entity by the time TaxBandits is contacted" do
    legal_entity_at_submission = :not_called
    allow(TaxbanditsService).to receive(:create_from_data) do |payload|
      legal_entity_at_submission = Tax::Form.find_by_public_id(payload["PayeeRef"]).legal_entity
      { "SubmissionId" => "sub-1" }
    end

    result = run

    expect(legal_entity_at_submission).to eq(result.legal_entity)
  end

  describe "when the legal entity can't be created" do
    before { allow(LegalEntity).to receive(:create!).and_raise(ActiveRecord::RecordInvalid) }

    it "neither contacts TaxBandits nor leaves the staged PDF behind" do
      allow(Tax::W9PdfStore).to receive(:discard).and_call_original

      expect { run(data: business_data) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(TaxbanditsService).not_to have_received(:create_from_data)
      expect(Tax::W9PdfStore).to have_received(:discard)
    end
  end

  describe "completed_at" do
    it "is when the W-9 was completed in Tax1099, not when it was imported" do
      travel_to Time.zone.local(2026, 11, 14, 12) do
        expect(run.form.completed_at).to eq(Time.zone.local(2025, 3, 7))
      end
    end

    it "lets a W-9 the payee completed since outrank the imported one" do
      user = create(:user, email: "ada@example.com")
      newer = create(:tax_form, :completed, legal_entity: user.personal_legal_entity, completed_at: 1.week.ago)

      imported = run.form

      expect(user.personal_legal_entity.reload.latest_completed_tax_form).to eq(newer)
      expect(imported.completed_at).to be < newer.completed_at
    end

    it "outranks a W-9 the payee completed before it" do
      user = create(:user, email: "ada@example.com")
      create(:tax_form, :completed, legal_entity: user.personal_legal_entity, completed_at: Time.zone.local(2024, 1, 1))

      imported = run.form

      expect(user.personal_legal_entity.reload.latest_completed_tax_form).to eq(imported)
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

      it "refuses the row when no entity was chosen" do
        expect { run(data: business_data) }
          .to raise_error(described_class::ValidationError, /pick one/)
      end

      it "neither creates a form nor contacts TaxBandits when no entity was chosen" do
        expect { run(data: business_data) rescue nil }.not_to change(Tax::Form, :count)
        expect(TaxbanditsService).not_to have_received(:create_from_data)
      end

      it "uses the entity the admin chose" do
        result = run(data: business_data, legal_entity: existing)

        expect(result.form.legal_entity).to eq(existing)
      end

      it "creates a new entity when the admin chose to" do
        result = run(data: business_data, new_legal_entity: true)

        expect(result.legal_entity).not_to eq(existing)
        expect(result.legal_entity).to have_attributes(name: "Analytical Engines LLC", entity_type: "business")
        expect(result.form.legal_entity).to eq(result.legal_entity)
      end

      it "refuses an entity belonging to somebody else" do
        stranger = create(:legal_entity, entity_type: :business, users: [create(:user)])

        expect { run(data: business_data, legal_entity: stranger) }
          .to raise_error(described_class::ValidationError, /not one of/)
      end

      it "refuses the payee's personal entity for a business form" do
        expect { run(data: business_data, legal_entity: user.personal_legal_entity) }
          .to raise_error(described_class::ValidationError, /not one of/)
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

    context "when a concurrent import of the same TIN wins the race" do
      # Simulates the losing side: the up-front check ran before the winner
      # committed, so it saw nothing, but by the time this import writes the TIN
      # the winner's form is there.
      let!(:winner) { run.form }

      before do
        calls = 0
        allow_any_instance_of(described_class).to receive(:duplicate_tax1099_form).and_wrap_original do |original|
          (calls += 1) == 1 ? nil : original.call
        end
      end

      it "reports the winner as a duplicate" do
        expect { run }.to raise_error(described_class::DuplicateError) { |error|
          expect(error.existing_form).to eq(winner)
        }
      end

      it "fails before anything is sent to TaxBandits" do
        run rescue nil

        expect(TaxbanditsService).to have_received(:create_from_data).once # the winner's
      end

      it "leaves no second form behind and discards its staged PDF" do
        allow(Tax::W9PdfStore).to receive(:discard).and_call_original

        expect { run rescue nil }.not_to change(Tax::Form.with_deleted, :count)
        expect(Tax::W9PdfStore).to have_received(:discard)
      end
    end

    describe "the unique index" do
      let(:tin_hash) { run.form.tin_hash }

      it "refuses a second live tax1099 form for the same TIN" do
        expect { create(:tax_form, :completed, source: :tax1099, tin_hash:) }
          .to raise_error(ActiveRecord::RecordNotUnique, /#{described_class::UNIQUE_TIN_INDEX}/o)
      end

      it "ignores forms from other sources" do
        expect { create(:tax_form, :completed, source: :taxbandits, tin_hash:) }.not_to raise_error
      end

      it "ignores discarded and deleted tax1099 forms" do
        Tax::Form.tax1099.find_by(tin_hash:).update!(aasm_state: "discarded")
        create(:tax_form, :completed, source: :tax1099, tin_hash:).destroy!

        expect { create(:tax_form, :completed, source: :tax1099, tin_hash:) }.not_to raise_error
      end
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

    it "rejects a completed date that isn't a date" do
      expect { run(data: person_data.merge(completed_on: "03/07/2025")) }
        .to raise_error(described_class::ValidationError, /YYYY-MM-DD/)
    end

    it "rejects a completed date in the future" do
      expect { run(data: person_data.merge(completed_on: 1.day.from_now.to_date.iso8601)) }
        .to raise_error(described_class::ValidationError, /future/)
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
        .and_raise(Faraday::UnprocessableEntityError, "422: {\"Errors\":[{\"Message\":\"TIN 123-45-6789 is invalid\"}]}")
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
      expect { run rescue nil }.not_to change(Tax::Form.with_deleted, :count)
    end

    it "removes the business legal entity it created, but keeps the payee's user" do
      run(data: business_data) rescue nil

      user = User.find_by(email: "ada@example.com")
      expect(user).to be_present
      expect(user.legal_entities).to contain_exactly(user.personal_legal_entity)
    end

    it "leaves a legal entity the admin picked alone" do
      user = create(:user, email: "ada@example.com")
      existing = create(:legal_entity, name: "Engines Co", entity_type: :business, users: [user])

      run(data: business_data, legal_entity: existing) rescue nil

      expect(existing.reload.users).to contain_exactly(user)
    end

    it "never gives the legal entity the rejected TIN" do
      run rescue nil

      expect(User.find_by(email: "ada@example.com").personal_legal_entity.reload.tin_hash).to be_nil
    end

    it "lets the corrected row be imported afterwards" do
      run rescue nil
      allow(TaxbanditsService).to receive(:create_from_data).and_return({ "SubmissionId" => "sub-2" })

      expect(run.form).to have_attributes(aasm_state: "completed", external_id: "sub-2")
    end

    it "discards the staged PDF instead of leaving it to sit out its TTL" do
      allow(Tax::W9PdfStore).to receive(:discard).and_call_original

      run rescue nil

      expect(Tax::W9PdfStore).to have_received(:discard)
    end
  end

  describe "the TaxBandits call" do
    it "is made outside any transaction, after the form is committed" do
      baseline = ActiveRecord::Base.connection.open_transactions
      open_during_call = nil
      committed_form = nil
      allow(TaxbanditsService).to receive(:create_from_data) do |payload|
        open_during_call = ActiveRecord::Base.connection.open_transactions
        committed_form = Tax::Form.find_by_public_id(payload["PayeeRef"])
        { "SubmissionId" => "sub-1" }
      end

      run

      expect(open_during_call).to eq(baseline)
      expect(committed_form).to have_attributes(aasm_state: "sent")
    end
  end

  describe "TIN verification" do
    before { allow_any_instance_of(LegalEntity).to receive(:requires_tax_verification?).and_return(true) }

    it "counts an imported form as verified, though TaxBandits never matches its TIN" do
      result = run

      expect(result.form.taxbandits_tin_matching_status).to be_nil
      expect(result.form).to be_tin_verified
      expect(result.legal_entity.reload.pending_payable_requirements).not_to include(:form_verified)
    end

    it "stays verified after a TaxBandits sync reports no TIN match" do
      result = run
      allow(TaxbanditsService).to receive(:get_submission).and_return(nil)
      allow(TaxbanditsService).to receive(:get_status).and_return({ "FormStatus" => "COMPLETED", "TINMatching" => nil })

      result.form.sync_with_taxbandits

      expect(result.legal_entity.reload.pending_payable_requirements).not_to include(:form_verified)
    end

    it "still needs a TIN match for a form collected through TaxBandits" do
      user = create(:user, email: "grace@example.com")
      create(:tax_form, :completed, legal_entity: user.personal_legal_entity)

      expect(user.personal_legal_entity.reload.pending_payable_requirements).to include(:form_verified)
    end
  end

  describe "on success" do
    it "gives the legal entity the form's TIN identity" do
      result = run

      expect(result.legal_entity.reload.tin_hash).to eq(result.form.tin_hash)
    end

    it "sends no completion email" do
      expect { run }.not_to have_enqueued_mail(Tax::FormMailer, :completed)
    end
  end

  describe "when the payload can't be built" do
    before { allow_any_instance_of(described_class).to receive(:build_payload).and_raise(NoMethodError) }

    it "sends nothing, keeps no form, and discards the PDF" do
      allow(Tax::W9PdfStore).to receive(:discard).and_call_original

      expect { run }.to raise_error(NoMethodError)

      expect(TaxbanditsService).not_to have_received(:create_from_data)
      expect(Tax::Form.with_deleted.count).to eq(0)
      expect(Tax::W9PdfStore).to have_received(:discard)
    end
  end

  it "still succeeds if refreshing the payee's payments fails afterwards" do
    allow_any_instance_of(LegalEntity).to receive(:refresh_pending_contractors_payments!).and_raise("boom")

    expect(run.form).to have_attributes(aasm_state: "completed", external_id: "sub-1")
  end

  describe "when TaxBandits accepts the submission without a submission id" do
    before { allow(TaxbanditsService).to receive(:create_from_data).and_return({ "StatusCode" => 200 }) }

    it "keeps the form as sent and reports the outcome as unconfirmed" do
      expect { run }.to raise_error(described_class::UncertainSubmissionError) { |error|
        expect(error.form.reload).to have_attributes(aasm_state: "sent", external_id: nil)
      }
    end
  end

  describe "when recording an accepted submission fails" do
    before do
      allow_any_instance_of(Tax::Form).to receive(:adopt_tin_hash_on_legal_entity!).and_raise(ActiveRecord::ConnectionFailed)
    end

    it "keeps the form as sent and tells the admin the submission id" do
      expect { run }.to raise_error(described_class::UncertainSubmissionError) { |error|
        expect(error.message).to include("sub-1")
        expect(error.form.reload).to have_attributes(aasm_state: "sent", external_id: nil)
      }
    end
  end

  describe "when TaxBandits doesn't say whether it accepted the submission" do
    [
      Faraday::TimeoutError.new("Net::ReadTimeout with #<TCPSocket:(closed)>"),
      Faraday::ConnectionFailed.new("Connection reset by peer"),
      Faraday::ServerError.new("the server responded with status 503"),
    ].each do |error|
      context "(#{error.class})" do
        before { allow(TaxbanditsService).to receive(:create_from_data).and_raise(error) }

        it "keeps the form, as sent rather than completed, with no submission id" do
          expect { run }.to raise_error(described_class::UncertainSubmissionError) { |raised|
            expect(raised.form.reload).to have_attributes(
              source: "tax1099", aasm_state: "sent", external_id: nil,
              completed_at: Time.zone.local(2025, 3, 7), tin_hash: be_present
            )
            expect(raised.message).to include(raised.form.public_id)
          }
        end
      end
    end

    before do
      allow(TaxbanditsService).to receive(:create_from_data)
        .and_raise(Faraday::TimeoutError, "Net::ReadTimeout with #<TCPSocket:(closed)>")
    end

    it "keeps the user and legal entity too" do
      form = begin
        run(data: business_data)
      rescue described_class::UncertainSubmissionError => e
        e.form
      end

      expect(form.legal_entity.reload).to have_attributes(name: "Analytical Engines LLC")
      expect(User.find_by(email: "ada@example.com")).to be_present
    end

    it "leaves the staged PDF for TaxBandits to fetch" do
      allow(Tax::W9PdfStore).to receive(:discard).and_call_original

      run rescue nil

      expect(Tax::W9PdfStore).not_to have_received(:discard)
    end

    it "sends no completion email" do
      expect { run rescue nil }.not_to have_enqueued_mail(Tax::FormMailer, :completed)
    end

    it "catches a retry of the same row as a duplicate instead of submitting it again" do
      first = begin
        run
      rescue described_class::UncertainSubmissionError => e
        e.form
      end

      expect { run }.to raise_error(described_class::DuplicateError) { |error|
        expect(error.existing_form).to eq(first)
      }
      expect(TaxbanditsService).to have_received(:create_from_data).once
    end

    it "doesn't give the legal entity the TIN yet" do
      run rescue nil

      expect(User.find_by(email: "ada@example.com").personal_legal_entity.reload.tin_hash).to be_nil
    end

    it "keeps the row hidden next session" do
      run rescue nil

      expect(described_class.imported_row_keys).to eq(["ada@example.com|2025-03-07|person|05482"])
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

  describe "a W-8BEN row" do
    it "creates a completed W-8BEN on the payee's personal legal entity, addressed in their country" do
      result = run(data: w8ben_data)

      expect(result.form).to have_attributes(
        form_type: "W8BEN", entity_type: "person", tin_type: "foreign", aasm_state: "completed",
        address_city: "Ghaziabad", address_state: "Uttar Pradesh", address_postal_code: "201014",
        address_country: "IN"
      )
      expect(result.legal_entity).to eq(User.find_by(email: "sommaiya@example.com").personal_legal_entity)
    end

    it "fingerprints the foreign TIN within its country" do
      result = run(data: w8ben_data)

      expect(result.form.tin_hash).to eq(
        Tax::IdentificationNumber::Hasher.hash_tin("ABCDE1234F", tin_type: :foreign, country: "IN")
      )
    end

    it "sends the W-8BEN data" do
      result = run(data: w8ben_data)

      expect(TaxbanditsService).to have_received(:create_from_data).with(
        hash_including(
          "FormType"  => "W8BEN",
          "PayeeRef"  => result.form.public_id,
          "FormW8Ben" => hash_including(
            "NmOfIndividual" => "Sommaiya Angrish", "CitizenOfCountry" => "IN",
            "ForeignTIN" => "ABCDE1234F",
            "PermanentAddress" => hash_including("City" => "Ghaziabad", "Country" => "IN", "PostalCd" => "201014"),
            "Signature" => { "SignerNm" => "Sommaiya Angrish" }
          )
        )
      )
    end

    it "doesn't need a federal tax classification, state, or postal code" do
      expect { run(data: w8ben_data.merge(state: "", zip_code: "")) }.not_to raise_error
    end

    it "needs a 2-letter country" do
      expect { run(data: w8ben_data.merge(country: "India")) }
        .to raise_error(described_class::ValidationError, /2-letter/)
    end

    it "only takes a foreign TIN" do
      expect { run(data: w8ben_data.merge(tin_type: "SSN")) }
        .to raise_error(described_class::ValidationError, /FTIN/)
    end

    it "is a duplicate of an earlier import of the same foreign TIN from the same country" do
      run(data: w8ben_data)

      expect { run(data: w8ben_data.merge(email: "other@example.com")) }.to raise_error(described_class::DuplicateError)
    end

    it "isn't a duplicate of the same foreign TIN from another country" do
      run(data: w8ben_data)

      expect { run(data: w8ben_data.merge(country: "GB")) }.not_to raise_error
    end
  end

  describe "a W-8 without a foreign TIN" do
    let(:tinless_data) { w8ben_data.merge(tin: "", tin_type: "", ftin_not_legally_required: "1") }

    it "imports when the form says an FTIN isn't legally required, with no fingerprint" do
      result = run(data: tinless_data)

      expect(result.form).to have_attributes(form_type: "W8BEN", tin_hash: nil, tin_type: nil, aasm_state: "completed")
      expect(TaxbanditsService).to have_received(:create_from_data).with(
        hash_including("FormW8Ben" => hash_including("ForeignTIN" => nil, "IsFTINNotLegallyRequired" => true))
      )
    end

    it "works for a W-8BEN-E too" do
      run(data: w8bene_data.merge(tin: "", tin_type: "", ftin_not_legally_required: "1"))

      expect(TaxbanditsService).to have_received(:create_from_data).with(
        hash_including("FormW8BENE" => hash_including("Part1" => hash_including("ForeignTIN" => nil, "IsFTINNotLegallyRequired" => true)))
      )
    end

    it "isn't taken for a duplicate of another payee's TIN-less import" do
      run(data: tinless_data)

      expect { run(data: tinless_data.merge(email: "someone-else@example.com")) }.not_to raise_error
    end

    it "is a duplicate of an earlier import of the same row" do
      first = run(data: tinless_data).form

      expect { run(data: tinless_data) }.to raise_error(described_class::DuplicateError) { |error|
        expect(error.existing_form).to eq(first)
      }
      expect(TaxbanditsService).to have_received(:create_from_data).once
    end

    it "matches the row however its email and postal code are written" do
      run(data: tinless_data)

      expect { run(data: tinless_data.merge(email: " Sommaiya@Example.com ", zip_code: "201 014")) }
        .to raise_error(described_class::DuplicateError)
    end

    it "is a duplicate of an earlier import left unconfirmed" do
      allow(TaxbanditsService).to receive(:create_from_data).and_raise(Faraday::TimeoutError, "timeout")
      run(data: tinless_data) rescue nil

      expect { run(data: tinless_data) }.to raise_error(described_class::DuplicateError)
    end

    it "isn't a duplicate once the earlier import is discarded" do
      run(data: tinless_data).form.update!(aasm_state: :discarded)

      expect { run(data: tinless_data) }.not_to raise_error
    end

    it "isn't a duplicate of a different form type or completed date" do
      run(data: tinless_data)

      expect { run(data: tinless_data.merge(completed_on: "2025-07-23")) }.not_to raise_error
      expect {
        run(data: tinless_data.merge(form_type: "W8BENE", first_name: "Sommaiya Studio", ch3_status: "CORPORATION"))
      }.not_to raise_error
    end

    it "isn't a duplicate of the same payee's form that has a TIN" do
      run(data: w8ben_data)

      expect { run(data: tinless_data) }.not_to raise_error
    end

    context "when a concurrent import of the same row wins the race" do
      # As with the TIN race: the up-front check saw nothing, but the winner has
      # committed by the time this one takes the row's lock.
      let!(:winner) { run(data: tinless_data).form }

      before do
        calls = 0
        allow_any_instance_of(described_class).to receive(:tinless_duplicate).and_wrap_original do |original|
          (calls += 1) == 1 ? nil : original.call
        end
      end

      it "reports the winner as a duplicate before anything is sent" do
        expect { run(data: tinless_data) }.to raise_error(described_class::DuplicateError) { |error|
          expect(error.existing_form).to eq(winner)
        }
        expect(TaxbanditsService).to have_received(:create_from_data).once # the winner's
      end
    end

    it "needs the box ticked when there's no TIN" do
      expect { run(data: tinless_data.merge(ftin_not_legally_required: "")) }
        .to raise_error(described_class::ValidationError, /enter the foreign TIN/)
    end

    it "can't both give a TIN and say one isn't required" do
      expect { run(data: w8ben_data.merge(ftin_not_legally_required: "1")) }
        .to raise_error(described_class::ValidationError, /can't also say/)
    end

    it "sends IsFTINNotLegallyRequired false when a TIN is given" do
      run(data: w8ben_data)

      expect(TaxbanditsService).to have_received(:create_from_data)
        .with(hash_including("FormW8Ben" => hash_including("IsFTINNotLegallyRequired" => false)))
    end
  end

  it "still needs a TIN on a W-9" do
    expect { run(data: person_data.merge(tin: "")) }
      .to raise_error(described_class::ValidationError, /TIN \(EIN\/SSN\/FTIN\)/)
  end

  describe "a W-8BEN-E row" do
    it "creates a business legal entity named after the organization" do
      result = run(data: w8bene_data)

      expect(result.form).to have_attributes(form_type: "W8BENE", entity_type: "business")
      expect(result.legal_entity).to have_attributes(name: "Krishna Studios Pvt Ltd", entity_type: "business")
    end

    it "sends the W-8BEN-E data" do
      run(data: w8bene_data)

      expect(TaxbanditsService).to have_received(:create_from_data).with(
        hash_including(
          "FormType"   => "W8BENE",
          "FormW8BENE" => {
            "Part1"  => hash_including(
              "NmOfOrganization" => "Krishna Studios Pvt Ltd", "CountryOfOrganization" => "IN",
              "Ch3Status" => "CORPORATION", "ForeignTIN" => "ABCDE1234F",
              "MailAdd" => hash_including("Country" => "IN")
            ),
            "Part30" => {
              "IsCapacityToSign" => true, "SignerNm" => "Ravi Krishna", "SignDate" => "2025-07-22T00:00:00"
            }
          }
        )
      )
    end

    it "needs a signer name" do
      expect { run(data: w8bene_data.merge(signer_name: "")) }
        .to raise_error(described_class::ValidationError, /Signer Name/)
    end

    it "needs a chapter 3 status" do
      expect { run(data: w8bene_data.merge(ch3_status: "")) }
        .to raise_error(described_class::ValidationError, /Chapter 3 Status/)
    end
  end

  it "rejects an unknown form type" do
    expect { run(data: person_data.merge(form_type: "W8ECI")) }
      .to raise_error(described_class::ValidationError, /form type/)
  end

  it "doesn't take a foreign TIN on a W-9" do
    expect { run(data: person_data.merge(tin_type: "FTIN")) }
      .to raise_error(described_class::ValidationError, /SSN, EIN/)
  end

  describe ".imported_row_keys" do
    it "is empty when nothing has been imported" do
      expect(described_class.imported_row_keys).to be_empty
    end

    it "keys a personal import by email, completed date, person, and ZIP" do
      run

      expect(described_class.imported_row_keys).to eq(["ada@example.com|2025-03-07|person|05482"])
    end

    it "keys a business import as a business, normalizing the email and ZIP" do
      run(data: business_data.merge(email: " Ada@Example.com ", zip_code: "05482-1234"))

      expect(described_class.imported_row_keys).to eq(["ada@example.com|2025-03-07|business|05482"])
    end

    it "keys a W-8BEN import as a person, keeping a non-US postal code whole" do
      run(data: w8ben_data.merge(zip_code: "sw1a 1aa"))

      expect(described_class.imported_row_keys).to eq(["sommaiya@example.com|2025-07-22|person|SW1A1AA"])
    end

    it "leaves out discarded imports" do
      run.form.update!(aasm_state: :discarded)

      expect(described_class.imported_row_keys).to be_empty
    end

    it "leaves out forms that didn't come from Tax1099" do
      user = create(:user, email: "grace@example.com")
      create(:tax_form, legal_entity: user.personal_legal_entity, source: :taxbandits, completed_at: Time.current)

      expect(described_class.imported_row_keys).to be_empty
    end
  end
end
