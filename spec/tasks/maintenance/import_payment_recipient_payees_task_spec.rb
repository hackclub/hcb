# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::ImportPaymentRecipientPayeesTask, type: :model do
  let(:event) { create(:event, :with_positive_balance) }

  def run_task
    task = described_class.new
    task.collection.each { |record| task.process(record) }
  end

  def ach_recipient(email: "orpheus@hackclub.com", account_number: "123456789", on: event, **attrs)
    create(:payment_recipient, event: on, email:, payment_model: "AchTransfer", name: "Orpheus",
                               routing_number: "021000021", account_number:, bank_name: "Chase", **attrs)
  end

  # Sending a transfer through a recipient overwrites the recipient's saved
  # details with the transfer's, as the old transfer form does.
  def ach_to(recipient, account_number: recipient.account_number, routing_number: "021000021", aasm_state: "deposited")
    create(:ach_transfer, event: recipient.event, payment_recipient: recipient, recipient_email: recipient.email,
                          recipient_name: recipient.name || "Orpheus", account_number:, routing_number:,
                          bank_name: "Chase", aasm_state:)
  end

  def paid_ach(email: "orpheus@hackclub.com", account_number: "123456789", **attrs)
    ach_recipient(email:, account_number:, **attrs).tap { |recipient| ach_to(recipient) }
  end

  def check_recipient
    create(:payment_recipient, event:, email: "orpheus@hackclub.com", name: "Orpheus", payment_model: "IncreaseCheck",
                               address_line1: "8605 Santa Monica Blvd", address_city: "West Hollywood",
                               address_state: "CA", address_zip: "90069")
  end

  def check_to(recipient, address_line1:, **attrs)
    IncreaseCheck.insert!({ event_id: event.id, payment_recipient_id: recipient.id, aasm_state: "approved",
                            address_line1:, address_city: "West Hollywood", address_state: "CA", address_zip: "90069",
                            created_at: Time.current, updated_at: Time.current, **attrs
})
  end

  # Validating a wire asks Column which country the bank is in.
  def stub_column_institution(country_code:)
    stub_request(:get, /api\.column\.com/).to_return(
      status: 200, body: { country_code: }.to_json, headers: { "Content-Type" => "application/json" }
    )
  end

  def paid_wire(**attrs)
    recipient = create(:payment_recipient, event:, email: "orpheus@hackclub.com", payment_model: "Wire", name: "Orpheus")
    create(:wire, :approved, event:, user: create(:user, :make_admin), payment_recipient: recipient,
                             recipient_email: recipient.email, recipient_name: "Orpheus", amount_cents: 100,
                             account_number: "GB29NWBK60161331926819", bic_code: "BARCGB22",
                             address_line1: "1 Hack Lane", address_city: "London", address_state: "London",
                             address_postal_code: "SW1A 1AA", recipient_country: :GB, **attrs)
  end

  def legal_entity
    event.payees.sole.legal_entity
  end

  it "runs from /maintenance_tasks, which can't iterate an ordered relation" do
    paid_ach

    MaintenanceTasks::Runner.run(name: described_class.name)
    perform_enqueued_jobs(only: MaintenanceTasks::TaskJob)

    expect(MaintenanceTasks::Run.last).to be_succeeded
    expect(event.payees.sole).to be_imported
  end

  it "collapses every recipient sharing an email into one imported payee" do
    paid_ach(account_number: "111111111")
    paid_ach(account_number: "222222222")

    run_task

    payee = event.payees.sole
    expect(payee).to be_imported
    expect(payee.email).to eq("orpheus@hackclub.com")
    expect(payee.legal_entity.managing_event).to eq(event)
    expect(payee.legal_entity.payout_methods.count).to eq(2)
  end

  it "keeps the same email in two events apart, since a managed entity belongs to one" do
    other_event = create(:event, :with_positive_balance)
    paid_ach
    ach_to(ach_recipient(on: other_event))

    run_task

    expect(event.payees.sole.legal_entity).not_to eq(other_event.payees.sole.legal_entity)
  end

  it "imports the details money went out on, not ones a later bounced transfer saved over them" do
    recipient = paid_ach(account_number: "111111111")
    travel_to(1.day.from_now) { ach_to(recipient, account_number: "222222222", aasm_state: "failed") }
    expect(recipient.reload.account_number).to eq("222222222")

    run_task

    expect(legal_entity.payout_methods.sole.details.account_number).to eq("111111111")
    expect(legal_entity.payout_methods.sole).to be_default
  end

  it "doesn't import details no money ever went out on" do
    %w[pending rejected failed].each { |aasm_state| ach_to(ach_recipient, aasm_state:) }

    expect { run_task }.not_to change(LegalEntity, :count)

    payee = event.payees.sole
    expect(payee).to be_imported
    expect(payee.legal_entity).to be_nil
  end

  it "defaults to the details money last went out on" do
    paid_ach(account_number: "111111111")
    travel_to(1.day.from_now) { paid_ach(account_number: "222222222") }
    travel_to(2.days.from_now) { ach_to(ach_recipient(account_number: "333333333"), aasm_state: "pending") }

    run_task

    expect(legal_entity.payout_methods.count).to eq(2)
    expect(legal_entity.default_payout_method.details.account_number).to eq("222222222")
  end

  it "leaves an email the payee flow already knows alone, so a re-run can't duplicate or hijack it" do
    payee = create(:payee, event:, email: "orpheus@hackclub.com", legal_entity: create(:legal_entity))
    paid_ach

    run_task
    run_task

    expect(event.payees.reload).to contain_exactly(payee)
    expect(payee.reload.legal_entity.payout_methods).to be_empty
    expect(payee).not_to be_imported
  end

  it "creates nothing on a re-run" do
    paid_ach

    run_task

    expect { run_task }.not_to(change { [Payee.count, LegalEntity.count, LegalEntity::PayoutMethod.count] })
  end

  it "recognizes an existing payee whose email predates normalization" do
    payee = create(:payee, event:, email: "orpheus@hackclub.com")
    # Raw SQL skips normalizes, reproducing a row saved before it existed.
    Payee.where(id: payee.id).update_all("email = ' Orpheus@HackClub.com '")
    paid_ach

    run_task

    expect(event.payees.reload).to contain_exactly(payee)
  end

  it "leaves behind and logs details that can no longer make a usable payout method, without a trace of the entity" do
    recipient = ach_recipient
    transfer = ach_to(recipient)
    transfer.update_columns(routing_number_ciphertext: AchTransfer.new(routing_number: "12345").routing_number_ciphertext)

    allow(Rails.logger).to receive(:warn).and_call_original
    expect(Rails.logger).to receive(:warn).with(/AchTransfer #{transfer.id} \(PaymentRecipient #{recipient.id}\) left behind/)

    expect { run_task }.not_to(change { [LegalEntity.count, PaperTrail::Version.where(item_type: "LegalEntity").count] })

    payee = event.payees.sole
    expect(payee).to be_imported
    expect(payee.legal_entity).to be_nil
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

  it "copies a paid check's address across as a check payout method" do
    check_to(check_recipient, address_line1: "8605 Santa Monica Blvd")

    run_task

    details = legal_entity.default_payout_method.details
    expect(details).to be_a(LegalEntity::PayoutMethod::Check)
    expect(details.address_line1).to eq("8605 Santa Monica Blvd")
    expect(details.address_postal_code).to eq("90069")
  end

  it "doesn't count a stopped check as money that went out" do
    recipient = check_recipient
    check_to(recipient, address_line1: "1 Stopped St", column_status: "stopped", created_at: 1.day.from_now)
    check_to(recipient, address_line1: "2 Cashed St")

    run_task

    expect(legal_entity.payout_methods.sole.details.address_line1).to eq("2 Cashed St")
  end

  it "copies a paid wire's details across as a wire payout method, without that one payment's purpose" do
    stub_column_institution(country_code: "GB")
    paid_wire(recipient_information: { "purpose_code" => "SRV", "remittance_info" => "Invoice 12", "phone" => "1234567890" })

    run_task

    details = legal_entity.default_payout_method.details
    expect(details).to be_a(LegalEntity::PayoutMethod::Wire)
    expect(details.recipient_country).to eq("GB")
    expect(details.bic_code).to eq("BARCGB22")
    expect(details.recipient_information).to eq("phone" => "1234567890")
  end

  it "leaves behind a wire whose details no longer make a valid method" do
    stub_column_institution(country_code: "GB")
    # SWIFT only carries the English alphabet, a rule added after this wire went out.
    paid_wire.update_columns(address_line1: "1 Hack Lañe")

    expect { run_task }.not_to change(LegalEntity, :count)
    expect(event.payees.sole.legal_entity).to be_nil
  end

  it "collapses transfers that repeat the same details into one payout method" do
    recipient = paid_ach
    2.times { ach_to(recipient) }
    paid_ach

    run_task

    expect(legal_entity.payout_methods.count).to eq(1)
  end

  it "names the payee from the most recently updated recipient that has a name" do
    # A reimbursement or payroll payout writes a recipient with no name, and it
    # must not bury the name someone actually typed in earlier.
    older = paid_ach(name: "Orpheus the Dinosaur")
    travel_to(1.day.from_now) { paid_ach(name: nil, account_number: "222222222") }
    # Every transfer overwrites its recipient's name, so the newest name lives
    # on the recipient updated last, not the one created last.
    travel_to(2.days.from_now) { older.update!(name: "Orpheus the Second") }

    run_task

    payee = event.payees.sole
    expect(payee.display_name).to eq("Orpheus the Second")
    expect(payee.legal_entity.name).to eq("Orpheus the Second")
  end

  it "falls back to the email when no recipient ever had a name" do
    # The legal entity's name is what gets sent to TaxBandits, so it can't be nil.
    ach_recipient(name: nil)

    run_task

    expect(event.payees.sole.display_name).to eq("orpheus@hackclub.com")
  end

  it "skips a recipient written behind a contractor payment, so an org can't take over the contractor's bank account" do
    # Renaming a payee's email leaves the recipient behind their past payments matching no payee.
    recipient = ach_recipient(email: "old-address@hackclub.com")
    create(:payment_attempt, payout: ach_to(recipient))

    expect { run_task }.not_to change(Payee, :count)
  end

  it "skips the reimbursement clearinghouse, whose every transfer is a payout HCB sends itself" do
    # A retried reimbursement repoints its holding to the new transfer, so the
    # failed one's recipient no longer looks system-generated on its own.
    clearinghouse = create(:event, :with_positive_balance, id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING)
    ach_to(ach_recipient(on: clearinghouse))

    expect { run_task }.not_to change(Payee, :count)
  end

  it "leaves an archived payee's email alone rather than bringing them back" do
    create(:payee, event:, email: "orpheus@hackclub.com", archived_at: Time.current)
    paid_ach

    expect { run_task }.not_to change(Payee, :count)
  end

  it "hands the default to the next method when the newest paid one can't be rebuilt" do
    paid_ach(account_number: "111111111")
    newest = travel_to(1.day.from_now) { ach_to(ach_recipient(account_number: "222222222")) }
    newest.update_columns(routing_number_ciphertext: AchTransfer.new(routing_number: "12345").routing_number_ciphertext)

    run_task

    expect(legal_entity.payout_methods.sole.details.account_number).to eq("111111111")
    expect(legal_entity.payout_methods.sole).to be_default
  end

  it "groups emails saved before they were normalized with their lowercase twins" do
    paid_ach(account_number: "111111111")
    legacy = paid_ach(account_number: "222222222")
    PaymentRecipient.unscoped.where(id: legacy.id).update_all(email: " Orpheus@HackClub.com ")

    run_task

    expect(legal_entity.payout_methods.count).to eq(2)
  end

  it "keeps the payee when a payout method hits a database error" do
    paid_ach
    allow_any_instance_of(LegalEntity::PayoutMethodService::Update).to receive(:run) do
      ActiveRecord::Base.connection.execute("SELECT 1/0")
    end

    expect { run_task }.not_to change(LegalEntity, :count)

    expect(event.payees.sole.legal_entity).to be_nil
  end
end
