# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tax1099Service::Import do
  def csv(*rows)
    ["Email,TIN,TIN Type,Form Type,Date Submitted,Name,Business Name,Country", *rows, ""].join("\n")
  end

  def row(email: "orpheus@hackclub.com", tin: "123456789", tin_type: "SSN", form_type: "W-9",
          date: "06/15/2023", name: "Orpheus Hackclub", business_name: "", country: "")
    [email, tin, tin_type, form_type, date, name, business_name, country].join(",")
  end

  def import(content, **options)
    described_class.new(csv: content, **options).run
  end

  def fingerprint(tin, tin_type: :individual, country: "US")
    Tax::IdentificationNumber::Hasher.hash_tin(tin, tin_type:, country:)
  end

  it "files against the entity already carrying the TIN, leaving its TaxBandits form the latest" do
    entity = create(:legal_entity, :person, tin_hash: fingerprint("123456789"))
    taxbandits_form = create(:tax_form, :completed, legal_entity: entity, tin_hash: entity.tin_hash, completed_at: 1.day.ago)

    result = import(csv(row))

    expect(result.imported).to eq(1)
    expect(entity.reload.latest_completed_tax_form).to eq(taxbandits_form)
    expect(entity.tax_forms.sent_with_manual.sole).to be_completed
  end

  it "keeps an export date that postdates the TaxBandits form from outranking it" do
    entity = create(:legal_entity, :person, tin_hash: fingerprint("123456789"))
    taxbandits_form = create(:tax_form, :completed, legal_entity: entity, tin_hash: entity.tin_hash, completed_at: "2020-01-01")

    import(csv(row(date: "06/15/2023")))

    expect(entity.reload.latest_completed_tax_form).to eq(taxbandits_form)
  end

  it "creates the user behind an SSN W-9 and identifies their personal entity by it" do
    result = import(csv(row(email: "new@hackclub.com")))

    entity = User.find_by(email: "new@hackclub.com").personal_legal_entity
    expect(result.imported).to eq(1)
    expect(entity.tax_forms.sole.form_type).to eq("W9")
    expect(entity.reload.tin_hash).to eq(fingerprint("123456789"))
  end

  it "gives an EIN its own business entity, named off the form, when the user has none" do
    user = create(:user, email: "boss@acme.com")

    import(csv(row(email: "boss@acme.com", tin: "987654321", tin_type: "EIN", business_name: "Acme Inc")))

    entity = user.legal_entities.find_by(entity_type: :business)
    expect(entity.name).to eq("Acme Inc")
    expect(entity.tax_forms.sole).to be_sent_with_manual
    expect(entity.reload.tin_hash).to eq(fingerprint("987654321", tin_type: :entity))
  end

  it "leaves an EIN for a human to place when the user already has a business entity" do
    user = create(:user, email: "boss@acme.com")
    create(:legal_entity_user, user:, legal_entity: create(:legal_entity, :business))

    result = import(csv(row(email: "boss@acme.com", tin: "987654321", tin_type: "EIN", business_name: "Acme Inc")))

    expect(result.imported).to eq(0)
    expect(result.review.sole).to include("boss@acme.com", "business legal entity")
    expect(Tax::Form.count).to eq(0)
  end

  it "refuses to file a TIN against an entity that reports a different one, which would strand it" do
    user = create(:user, email: "orpheus@hackclub.com")
    user.personal_legal_entity.update!(tin_hash: fingerprint("999999999"))

    result = import(csv(row))

    expect(result.review.sole).to include("different TIN")
    expect(Tax::Form.count).to eq(0)
    expect(user.personal_legal_entity.reload.tin_hash).to eq(fingerprint("999999999"))
  end

  it "fingerprints a W-8BEN's foreign TIN by the country that issued it" do
    result = import(csv(row(email: "amelie@lecole.fr", tin: "FR123456", tin_type: "FTIN", form_type: "W-8BEN", country: "FR")))

    entity = User.find_by(email: "amelie@lecole.fr").personal_legal_entity
    expect(result.imported).to eq(1)
    expect(entity.reload.tin_hash).to eq(fingerprint("FR123456", tin_type: :foreign, country: "FR"))
  end

  it "files nothing twice when the export is replayed" do
    content = csv(row)
    import(content)

    result = import(content)

    expect(result).to have_attributes(imported: 0, skipped: 1)
    expect(Tax::Form.count).to eq(1)
  end

  it "sends a W-9 that doesn't say which kind of TIN it carries to review rather than guessing" do
    result = import(csv(row(tin_type: "")))

    expect(result.review.sole).to include("SSN or an EIN")
    expect(Tax::Form.count).to eq(0)
  end

  it "keeps one unusable row from taking the rest of the export down with it" do
    result = import(csv(row(email: "not-an-email"), row(email: "orpheus@hackclub.com")))

    expect(result).to have_attributes(imported: 1, errors: ["Row 2 (not-an-email): email is missing or invalid"])
  end

  it "never repeats a TIN back in anything it reports" do
    result = import(csv(row(email: "not-an-email", tin: "123456789"), row(tin: "555443333", form_type: "W-4")))

    expect(result.errors.count).to eq(2)
    expect(result.errors.join).not_to include("123456789")
    expect(result.errors.join).not_to include("555443333")
  end

  it "writes nothing on a dry run" do
    import(csv(row), dry_run: true)

    expect(Tax::Form.count).to eq(0)
    expect(User.find_by(email: "orpheus@hackclub.com")).to be_nil
  end

  it "refuses an export that is missing a column it cannot work without, naming what it does have" do
    expect { import("Email,TIN\norpheus@hackclub.com,123456789\n") }
      .to raise_error(described_class::HeaderError, /form_type.*Email, TIN/m)
  end

  # Tax1099 lets whoever runs the export choose its headers, so neither the
  # header nor the value spellings below are a schema we can rely on.
  it "reads a column the aliases don't cover when it is named explicitly" do
    csv = "Email,Tax ID Number,TIN Type,Form Type,Signed On\n" \
          "orpheus@hackclub.com,123456789,SSN,W-9,06/15/2023\n"

    result = import(csv, columns: { tin: "Tax ID Number", completed_at: "Signed On" })

    expect(result.imported).to eq(1)
  end

  it "reports which header each field resolved to, without reading a row" do
    mapping = described_class.new(csv: csv(row), columns: { name: "Nope" }).column_mapping

    expect(mapping).to include(email: "Email", tin: "TIN", form_type: "Form Type", name: "Nope")
    expect(mapping[:address_line2]).to be_nil
  end

  it "matches a form type however the export spells it" do
    # A TIN each: two rows sharing one would be the same taxpayer, and the
    # second would rightly be skipped rather than filed again.
    ["W-9", "W9", "Form W-9"].each_with_index do |spelling, index|
      result = import(csv(row(email: "orpheus#{index}@hackclub.com", tin: "12345678#{index}", form_type: spelling)))

      expect(result.imported).to eq(1)
    end
  end

  it "keeps a W-8BEN-E off the W-8BEN entity type its name is a prefix of" do
    import(csv(row(email: "boss@acme.com", tin: "987654321", tin_type: "EIN",
                   form_type: "Form W-8BEN-E", business_name: "Acme Inc")))

    entity = User.find_by(email: "boss@acme.com").legal_entities.find_by(entity_type: :business)
    expect(entity.tax_forms.sole.form_type).to eq("W8BENE")
  end

  it "reads a TIN type that is spelt out rather than coded" do
    result = import(csv(row(email: "new@hackclub.com", tin_type: "Social Security Number")))

    expect(result.imported).to eq(1)
    expect(User.find_by(email: "new@hackclub.com").personal_legal_entity.tax_forms.sole).to be_entity_person
  end
end
