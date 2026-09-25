# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::ImportPaymentRecipientPayeesTask, type: :model do
  let(:event) { create(:event, :with_positive_balance) }

  def run_task
    task = described_class.new
    task.collection.each { |record| task.process(record) }
  end

  def ach_recipient(email:, account_number: "123456789", **attrs)
    create(:payment_recipient, event:, email:, payment_model: "AchTransfer", name: "Orpheus",
                               routing_number: "021000021", account_number:, bank_name: "Chase", **attrs)
  end

  def wire_recipient(email:, **attrs)
    create(:payment_recipient, event:, email:, payment_model: "Wire", name: "Orpheus",
                               account_number: "GB29NWBK60161331926819", bic_code: "BARCGB22",
                               address_line1: "1 Hack Lane", address_city: "London", address_state: "London",
                               address_postal_code: "SW1A 1AA", recipient_country: "GB", **attrs)
  end

  def check_recipient(address_line1: "8605 Santa Monica Blvd")
    create(:payment_recipient, event:, email: "orpheus@hackclub.com", name: "Orpheus", payment_model: "IncreaseCheck",
                               address_line1:, address_city: "West Hollywood", address_state: "CA", address_zip: "90069")
  end

  # Validating a wire asks Column which country the bank is in, so the import
  # can't run without an answer.
  def stub_column_institution(country_code:)
    stub_request(:get, /api\.column\.com/).to_return(
      status: 200, body: { country_code: }.to_json, headers: { "Content-Type" => "application/json" }
    )
  end

  def transfer_to(recipient, aasm_state:)
    create(:ach_transfer, :without_payment_details, event:, payment_recipient: recipient,
                                                    recipient_email: recipient.email, aasm_state:)
  end

  it "collapses every recipient sharing an email into one imported payee" do
    ach_recipient(email: "orpheus@hackclub.com", account_number: "111111111")
    ach_recipient(email: "orpheus@hackclub.com", account_number: "222222222")

    run_task

    payee = event.payees.sole
    expect(payee).to be_imported
    expect(payee.email).to eq("orpheus@hackclub.com")
    expect(payee.legal_entity.managing_event).to eq(event)
    expect(payee.legal_entity.payout_methods.count).to eq(2)
  end

  it "keeps the same email in two events apart, since a managed entity belongs to one" do
    other_event = create(:event)
    ach_recipient(email: "orpheus@hackclub.com")
    create(:payment_recipient, event: other_event, email: "orpheus@hackclub.com", payment_model: "AchTransfer",
                               name: "Orpheus", routing_number: "021000021", account_number: "123456789", bank_name: "Chase")

    run_task

    expect(event.payees.sole.legal_entity).not_to eq(other_event.payees.sole.legal_entity)
  end

  it "defaults to the method money last went out on, not the most recent recipient" do
    paid = ach_recipient(email: "orpheus@hackclub.com", account_number: "111111111")
    transfer_to(paid, aasm_state: "deposited")
    unpaid = ach_recipient(email: "orpheus@hackclub.com", account_number: "222222222")
    transfer_to(unpaid, aasm_state: "pending")

    run_task

    default = event.payees.sole.legal_entity.default_payout_method
    expect(default.details.account_number).to eq("111111111")
  end

  it "falls back to the most recent recipient when nothing was ever sent" do
    ach_recipient(email: "orpheus@hackclub.com", account_number: "111111111")
    travel_to(1.day.from_now) { ach_recipient(email: "orpheus@hackclub.com", account_number: "222222222") }

    run_task

    default = event.payees.sole.legal_entity.default_payout_method
    expect(default.details.account_number).to eq("222222222")
  end

  it "leaves an email the payee flow already knows alone, so a re-run can't duplicate or hijack it" do
    payee = create(:payee, event:, email: "orpheus@hackclub.com", legal_entity: create(:legal_entity))
    ach_recipient(email: "orpheus@hackclub.com")

    run_task
    run_task

    expect(event.payees.reload).to contain_exactly(payee)
    expect(payee.reload.legal_entity.payout_methods).to be_empty
    expect(payee).not_to be_imported
  end

  it "leaves behind details that can no longer make a usable payout method" do
    recipient = ach_recipient(email: "orpheus@hackclub.com")
    recipient.update!(routing_number: "12345")

    run_task

    payee = event.payees.sole
    expect(payee.legal_entity.payout_methods).to be_empty
    expect(payee.display_name).to eq("Orpheus")
  end

  it "skips a recipient with no email, since a payee cannot exist without one" do
    # The column is nullable and the format validation came later, so a legacy
    # row can carry no email at all. Saved unvalidated to reproduce one.
    recipient = build(:payment_recipient, event:, email: nil, payment_model: "AchTransfer", name: "Orpheus",
                                          routing_number: "021000021", account_number: "123456789", bank_name: "Chase")
    recipient.save!(validate: false)

    expect { run_task }.not_to change(Payee, :count)
  end

  it "copies a check recipient's address across as a check payout method" do
    check_recipient

    run_task

    details = event.payees.sole.legal_entity.default_payout_method.details
    expect(details).to be_a(LegalEntity::PayoutMethod::Check)
    expect(details.address_postal_code).to eq("90069")
  end

  it "copies a wire recipient's details across as a wire payout method" do
    stub_column_institution(country_code: "GB")
    wire_recipient(email: "orpheus@hackclub.com")

    run_task

    details = event.payees.sole.legal_entity.default_payout_method.details
    expect(details).to be_a(LegalEntity::PayoutMethod::Wire)
    expect(details.recipient_country).to eq("GB")
    expect(details.bic_code).to eq("BARCGB22")
  end

  it "leaves behind a wire whose saved details no longer make a valid method" do
    stub_column_institution(country_code: "GB")
    wire_recipient(email: "orpheus@hackclub.com", address_line1: nil)

    expect { run_task }.to change(Payee, :count).by(1)
    expect(event.payees.sole.legal_entity.payout_methods).to be_empty
  end

  it "collapses recipients that repeat the same details into one payout method" do
    # The old form saves a new recipient every time someone types details into
    # it, and the payout system writes one behind every modern transfer too, so
    # the same account recurs. Two identical methods are indistinguishable in
    # the payee's picker.
    3.times { ach_recipient(email: "orpheus@hackclub.com", account_number: "123456789") }

    run_task

    expect(event.payees.sole.legal_entity.payout_methods.count).to eq(1)
  end

  it "names the payee from the most recent recipient that has a name" do
    # A reimbursement or payroll payout writes a recipient with no name, and it
    # must not bury the name someone actually typed in earlier.
    ach_recipient(email: "orpheus@hackclub.com", name: "Orpheus the Dinosaur")
    travel_to(1.day.from_now) { ach_recipient(email: "orpheus@hackclub.com", name: nil, account_number: "222222222") }

    run_task

    payee = event.payees.sole
    expect(payee.display_name).to eq("Orpheus the Dinosaur")
    expect(payee.legal_entity.name).to eq("Orpheus the Dinosaur")
  end

  it "falls back to the email when no recipient ever had a name" do
    # The legal entity's name is what gets sent to TaxBandits, so it can't be nil.
    ach_recipient(email: "orpheus@hackclub.com", name: nil)

    run_task

    payee = event.payees.sole
    expect(payee.display_name).to eq("orpheus@hackclub.com")
    expect(payee.legal_entity.name).to eq("orpheus@hackclub.com")
  end

  it "logs what it left behind, since the payee gives no sign a method went missing" do
    recipient = ach_recipient(email: "orpheus@hackclub.com")
    recipient.update!(routing_number: "12345")

    expect(Rails.logger).to receive(:warn).with(/PaymentRecipient #{recipient.id} \(AchTransfer\) left behind/)

    run_task
  end

  it "skips a recipient written behind a contractor payment, so an org can't take over the contractor's bank account" do
    # Renaming a payee's email leaves the recipient behind their past payments matching no payee.
    recipient = ach_recipient(email: "old-address@hackclub.com")
    create(:payment_attempt, payout: transfer_to(recipient, aasm_state: "deposited"))

    expect { run_task }.not_to change(Payee, :count)
  end

  it "leaves an archived payee's email alone rather than bringing them back" do
    create(:payee, event:, email: "orpheus@hackclub.com", archived_at: Time.current)
    ach_recipient(email: "orpheus@hackclub.com")

    expect { run_task }.not_to change(Payee, :count)
  end

  it "doesn't count a stopped check as money that went out" do
    stopped = check_recipient(address_line1: "1 Stopped St")
    IncreaseCheck.insert!({ event_id: event.id, payment_recipient_id: stopped.id, aasm_state: "approved", column_status: "stopped" })
    travel_to(1.day.from_now) { check_recipient(address_line1: "2 Newer St") }

    run_task

    expect(event.payees.sole.legal_entity.default_payout_method.details.address_line1).to eq("2 Newer St")
  end

  it "hands the default to the next method when the one money last went out on can't be rebuilt" do
    paid = ach_recipient(email: "orpheus@hackclub.com", account_number: "111111111")
    transfer_to(paid, aasm_state: "deposited")
    paid.update!(routing_number: "12345")
    ach_recipient(email: "orpheus@hackclub.com", account_number: "222222222")

    run_task

    payout_methods = event.payees.sole.legal_entity.payout_methods
    expect(payout_methods.sole.details.account_number).to eq("222222222")
    expect(payout_methods.sole).to be_default
  end

  it "groups emails saved before they were normalized with their lowercase twins" do
    ach_recipient(email: "orpheus@hackclub.com", account_number: "111111111")
    legacy = ach_recipient(email: "orpheus@hackclub.com", account_number: "222222222")
    PaymentRecipient.unscoped.where(id: legacy.id).update_all(email: " Orpheus@HackClub.com ")

    run_task

    expect(event.payees.sole.legal_entity.payout_methods.count).to eq(2)
  end

  it "keeps the payee when a payout method hits a database error" do
    ach_recipient(email: "orpheus@hackclub.com")
    allow_any_instance_of(LegalEntity::PayoutMethodService::Update).to receive(:run) do
      ActiveRecord::Base.connection.execute("SELECT 1/0")
    end

    run_task

    expect(event.payees.sole.legal_entity.payout_methods).to be_empty
  end
end
