# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tax::FormService::ImportTax1099 do
  def csv(*rows, headers: ["Email", "Name", "Form Type", "TIN", "TIN Type", "Received Date", "TIN Match"])
    CSV.generate { |out| [headers, *rows].each { |row| out << row } }
  end

  def import(*rows, commit: true, **options)
    described_class.new(csv: csv(*rows, **options.slice(:headers)), commit:, form_type: options[:form_type]).run
  end

  def fingerprint(tin, tin_type: :individual)
    Tax::IdentificationNumber::Hasher.hash_tin(tin, tin_type:, country: "US")
  end

  def old_system_payee(email, event: create(:event))
    create(:payee, event:, email:, imported_at: Time.current, legal_entity: LegalEntity.create!(managing_event: event, name: "Orpheus")).legal_entity
  end

  it "reads a Tax1099 W-9 report and never keeps or prints the raw TIN" do
    user = create(:user, email: "orpheus@hackclub.com")

    output = import(["Orpheus@HackClub.com ", "Orpheus", "123-45-6789", "3/4/21"], headers: ["Email Address", "Payee Name", "EIN/SSN", "Date Received"], form_type: "W9")

    form = user.legal_entities.person.sole.tax_forms.sole
    expect(form).to have_attributes(form_type: "W9", entity_type: "person", tin_hash: fingerprint("123456789"), completed_at: Date.new(2021, 3, 4).in_time_zone)
    stored = [*Tax::Form.all, *LegalEntity.all].flat_map { |record| record.attributes.values }.join(" ")
    expect("#{stored} #{output.join(" ")}").not_to match(/123-?45-?6789/)
  end

  it "saves nothing and never starts a payout in a dry run" do
    create(:user, email: "orpheus@hackclub.com")
    expect_any_instance_of(LegalEntity).not_to receive(:refresh_pending_contractors_payments!)

    expect { import(["orpheus@hackclub.com", "Orpheus", "W9", "123456789", "SSN"], commit: false) }
      .not_to(change { [Tax::Form.count, LegalEntity.count] })
  end

  it "can be re-run without duplicating anything" do
    create(:user, email: "orpheus@hackclub.com")
    rows = [["orpheus@hackclub.com", "Orpheus", "W9", "123456789", "SSN"], ["nobody@hackclub.com", "Nobody", "W9", "987654321", "SSN"]]

    import(*rows)

    expect { import(*rows) }.not_to(change { [Tax::Form.count, LegalEntity.count] })
  end

  it "adds the old form to an entity already known by its TIN without outranking the entity's own form" do
    entity = create(:legal_entity, :person, tin_hash: fingerprint("123456789"))
    own_form = create(:tax_form, :completed, legal_entity: entity, tin_hash: entity.tin_hash, completed_at: 1.month.ago)

    import(["someone-else@hackclub.com", "Orpheus", "W9", "123456789", "SSN", Date.current.strftime("%m/%d/%Y")])

    expect(entity.tax_forms.count).to eq(2)
    expect(entity.reload.latest_completed_tax_form).to eq(own_form)
  end

  it "makes a business legal entity named on the form for a user without one, but leaves a user who has one to a human" do
    newcomer = create(:user, email: "newcomer@hackclub.com")
    owner = create(:user, email: "owner@hackclub.com")
    owner.legal_entities.create!(entity_type: :business, name: "Existing LLC")

    output = import(["newcomer@hackclub.com", "Acme LLC", "W9", "12-3456789", "EIN"], ["owner@hackclub.com", "Other LLC", "W9", "98-7654321", "EIN"])

    expect(newcomer.legal_entities.business.sole).to have_attributes(name: "Acme LLC", tin_hash: fingerprint("12-3456789", tin_type: :entity))
    expect(owner.legal_entities.pluck(:name)).not_to include("Other LLC")
    expect(Tax::Form.unclaimed.sole.import_email).to eq("owner@hackclub.com")
    expect(output).to include(a_string_including("owner@hackclub.com's W9 needs someone to pick its legal entity"))
  end

  it "won't give a personal legal entity a form under a different TIN, which would make it unpayable" do
    user = create(:user, email: "orpheus@hackclub.com")
    personal = user.legal_entities.person.sole
    personal.update!(tin_hash: fingerprint("111111111"))

    import(["orpheus@hackclub.com", "Orpheus", "W9", "123456789", "SSN"])

    expect(personal.tax_forms).to be_empty
    expect(personal.reload.mismatched_tax_form).to be_nil
  end

  it "gives every old-system payee their form, but not a payee someone typed in by hand" do
    first = old_system_payee("orpheus@hackclub.com")
    second = old_system_payee("orpheus@hackclub.com")
    event = create(:event)
    typed_in = LegalEntity.create!(managing_event: event, name: "Orpheus", entity_type: :person)
    create(:payee, event:, email: "orpheus@hackclub.com", legal_entity: typed_in)

    import(["orpheus@hackclub.com", "Orpheus", "W9", "123456789", "SSN", nil, "Success"])

    [first, second].each do |entity|
      expect(entity.reload).to have_attributes(entity_type: "person", tin_hash: fingerprint("123456789"))
      expect(entity).to be_payable
    end
    expect(typed_in.tax_forms).to be_empty
  end

  it "records the TIN match, so a payee over the threshold whose W-9 didn't match is asked for a new form" do
    matched, unmatched, unknown = %w[matched unmatched unknown].map { |name| old_system_payee("#{name}@hackclub.com") }
    allow_any_instance_of(Tax::IdentificationNumber).to receive(:predicted_to_be_over_threshold?).and_return(true)

    import(
      ["matched@hackclub.com", "A", "W9", "111111111", "SSN", nil, "Success"],
      ["unmatched@hackclub.com", "B", "W9", "222222222", "SSN", nil, "Not Matched"],
      ["unknown@hackclub.com", "C", "W9", "333333333", "SSN"]
    )

    expect(matched.reload).to be_payable
    [unmatched, unknown].each do |entity|
      expect(entity.reload).not_to be_payable
      expect(entity.latest_completed_tax_form).to be_tin_match_failed
    end
  end

  it "leaves an old-system payee alone when its email has both a personal and a business form" do
    entity = old_system_payee("orpheus@hackclub.com")

    output = import(["orpheus@hackclub.com", "Orpheus", "W9", "123456789", "SSN"], ["orpheus@hackclub.com", "Orpheus LLC", "W9", "12-3456789", "EIN"])

    expect(entity.tax_forms).to be_empty
    expect(output).to include(a_string_including("orpheus@hackclub.com has 2 forms that fit #{entity.public_id}"))
  end

  it "parks a form nobody owns yet until its filer signs up" do
    import(["future@hackclub.com", "Future", "W8-BEN", nil, nil, "01/02/2024"])
    parked = Tax::Form.sole
    expect(parked).to have_attributes(aasm_state: "unclaimed", legal_entity: nil)

    user = create(:user, email: "future@hackclub.com")

    expect(parked.reload.legal_entity).to eq(user.legal_entities.person.sole)
    expect(parked).to be_completed
  end

  it "rejects an export with no header row without echoing the TIN it starts with" do
    expect { import(["orpheus@hackclub.com", "W9", "123-45-6789", "SSN"], headers: ["orpheus@hackclub.com", "W9", "987-65-4321", "SSN"]) }.to raise_error(ArgumentError) do |error|
      expect(error.message).to include("a tin column (tin, ein/ssn")
      expect(error.message).not_to match(/6789|4321|orpheus/)
    end
  end

  it "skips rows it can't trust, saying which, without printing their TINs" do
    output = import(
      ["orpheus@hackclub.com", "Orpheus", "W9", "123456789", nil],
      ["orpheus@hackclub.com", "Orpheus", "W9", nil, "SSN"],
      [nil, "Orpheus", "W9", "987654321", "SSN"],
      ["orpheus@hackclub.com", "Orpheus", "1099-NEC", "123456789", "SSN"]
    )

    expect(Tax::Form.count).to eq(0)
    expect(output.join).to include("Row 2 has an unknown TIN type", "Row 3 is a W-9 with no TIN", "Row 4 has no email", "Row 5 has an unknown form type")
    expect(output.join).not_to match(/123456789|987654321/)
  end
end
