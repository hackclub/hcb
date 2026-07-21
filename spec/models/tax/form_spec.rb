# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tax::Form, type: :model do
  let(:legal_entity) { create(:legal_entity, :person) }

  def w9_submission(tin: "123456789", tin_type: "SSN")
    {
      "FormType" => "FormW9",
      "FormW9"   => {
        "FormData" => {
          "TINType" => tin_type,
          "TIN"     => tin,
          "Address" => {
            "Address1" => "1 Main St",
            "City"     => "New York",
            "State"    => "NY",
            "ZipCd"    => "10001",
            "Country"  => "US"
          }
        }
      }
    }
  end

  describe "#import_taxbandits_data" do
    let(:form) { create(:tax_form, :sent, legal_entity:) }

    before do
      allow(TaxbanditsService).to receive(:get_submission).and_return(w9_submission)
    end

    it "stores a fingerprint of the TIN rather than the TIN itself" do
      form.mark_completed!

      expect(form.reload.tin_hash).to be_present
      expect(form.tin_hash).not_to include("123456789")
      expect(form.attributes.values.map(&:to_s)).not_to include(a_string_including("123456789"))
    end

    it "stores the entity type so no later request has to re-fetch the submission" do
      form.mark_completed!

      expect(form.reload.entity_type).to eq("person")
      expect(form.form_type).to eq("W9")
      expect(form.address_city).to eq("New York")
    end

    it "records a business W-9 as a business" do
      allow(TaxbanditsService).to receive(:get_submission).and_return(w9_submission(tin_type: "EIN"))

      form.mark_completed!

      expect(form.reload.entity_type).to eq("business")
    end

    it "copies the fingerprint onto a legal entity that has none" do
      form.mark_completed!

      expect(legal_entity.reload.tin_hash).to eq(form.reload.tin_hash)
    end

    it "does not let a form of the wrong entity type claim the legal entity's TIN" do
      # A business W-9 filed against a personal legal entity: the fingerprint lands
      # on the form, but must not become the personal entity's identity.
      allow(TaxbanditsService).to receive(:get_submission).and_return(w9_submission(tin_type: "EIN"))

      form.mark_completed!

      expect(form.reload.tin_hash).to be_present
      expect(legal_entity.reload.tin_hash).to be_nil
      expect(legal_entity).not_to be_payable
    end

    it "fingerprints the same taxpayer identically across two forms" do
      form.mark_completed!

      other = create(:tax_form, :sent, legal_entity: create(:legal_entity, :person))
      other.mark_completed!

      expect(other.reload.tin_hash).to eq(form.reload.tin_hash)
    end

    it "namespaces a foreign TIN by its country of residence, not its mailing address" do
      w8 = {
        "FormType"  => "FormW8BEN",
        "FormW8Ben" => {
          "FormData" => {
            "USTIN"            => nil,
            "ForeignTIN"       => "FTIN123",
            "PermanentAddress" => { "Country" => "DE" },
            "MailAdd"          => { "Address1" => "1 Fwd St", "City" => "New York", "State" => "NY", "ZipCd" => "10001", "Country" => "US" }
          }
        }
      }
      allow(TaxbanditsService).to receive(:get_submission).and_return(w8)

      form.mark_completed!
      de_hash = form.reload.tin_hash

      other = create(:tax_form, :sent, legal_entity: create(:legal_entity, :person))
      allow(TaxbanditsService).to receive(:get_submission).and_return(
        w8.deep_merge("FormW8Ben" => { "FormData" => { "PermanentAddress" => { "Country" => "GB" } } })
      )
      other.mark_completed!

      expect(de_hash).to be_present
      expect(de_hash).not_to eq(other.reload.tin_hash)
    end

    it "leaves the fingerprint nil when a foreign TIN has no determinable country" do
      w8 = {
        "FormType"  => "FormW8BEN",
        "FormW8Ben" => {
          "FormData" => {
            "USTIN"      => nil,
            "ForeignTIN" => "FTIN123",
            "MailAdd"    => { "Address1" => "1 St", "City" => "Berlin", "ZipCd" => "10115", "Country" => nil }
          }
        }
      }
      allow(TaxbanditsService).to receive(:get_submission).and_return(w8)

      form.mark_completed!

      expect(form.reload.tin_hash).to be_nil
    end

    it "does not put a TIN in the error it raises when the import fails" do
      allow(TaxbanditsService).to receive(:get_submission).and_raise("upstream said 123456789")

      expect { form.mark_completed! }.to raise_error(Tax::Form::ImportError) do |error|
        expect(error.message).not_to include("123456789")
        expect(error.cause).to be_nil
      end
    end
  end

  describe "a manually entered form" do
    let(:form) { create(:tax_form, :manual, :sent, legal_entity:) }

    it "never contacts TaxBandits to sync" do
      expect(TaxbanditsService).not_to receive(:get_status)

      form.sync_with_taxbandits
    end

    it "never contacts TaxBandits to import on completion" do
      expect(TaxbanditsService).not_to receive(:get_submission)

      form.mark_completed!

      expect(form.reload).to be_completed
    end

    it "has no masked TIN to show" do
      expect(TaxbanditsService).not_to receive(:get_list_entry)

      expect(form.masked_tin).to be_nil
    end
  end

  describe "#masked_tin" do
    let(:form) { create(:tax_form, :completed, legal_entity:) }

    it "returns the mask TaxBandits already applied" do
      allow(TaxbanditsService).to receive(:get_list_entry).and_return({ "TIN" => "XXXXX6789" })

      expect(form.masked_tin).to eq("XXXXX6789")
    end

    it "masks a TIN that TaxBandits returned unmasked" do
      allow(TaxbanditsService).to receive(:get_list_entry).and_return({ "TIN" => "123456789" })

      expect(form.masked_tin).to eq("XXXXX6789")
    end

    it "reads from TaxBandits only once per form" do
      allow(TaxbanditsService).to receive(:get_list_entry).and_return({ "TIN" => "XXXXX6789" })

      3.times { form.masked_tin }

      expect(TaxbanditsService).to have_received(:get_list_entry).once
    end
  end

  describe "TIN immutability" do
    it "refuses to change a fingerprint once it is set" do
      form = create(:tax_form, :completed, legal_entity:, tin_hash: "abc")

      form.tin_hash = "def"

      expect(form).not_to be_valid
      expect(form.errors[:tin_hash]).to include("cannot change once set")
    end
  end
end
