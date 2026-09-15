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
    # Saved unvalidated: the email format validation postdates these rows, so prod
    # carries recipients the factory can no longer create.
    recipient = build(:payment_recipient, event:, email: nil, payment_model: "AchTransfer", name: "Orpheus",
                                          routing_number: "021000021", account_number: "123456789", bank_name: "Chase")
    recipient.save!(validate: false)

    expect { run_task }.not_to change(Payee, :count)
  end

  context "wire recipients" do
    before do
      stub_request(:get, /api\.column\.com\/institutions/)
        .to_return(status: 200, body: '{"country_code":"GB"}', headers: { "Content-Type" => "application/json" })
    end

    def wire_recipient(**attrs)
      create(:payment_recipient, event:, email: "orpheus@hackclub.com", name: "Orpheus", payment_model: "Wire",
                                 account_number: "GB29NWBK60161331926819", bic_code: "NWBKGB2L",
                                 address_line1: "1 Main", address_line2: "", address_city: "London",
                                 address_state: "England", address_postal_code: "SW1A 1AA",
                                 recipient_country: "GB", recipient_information: {}, **attrs)
    end

    it "copies a wire recipient's details across as a wire payout method" do
      wire_recipient

      run_task

      details = event.payees.sole.legal_entity.default_payout_method.details
      expect(details).to be_a(LegalEntity::PayoutMethod::Wire)
      expect(details.bic_code).to eq("NWBKGB2L")
      expect(details.recipient_country).to eq("GB")
    end

    # Wire validations dereference these fields rather than checking presence, so a
    # legacy row missing one raises instead of failing validation.
    it "leaves behind a wire whose validations raise rather than aborting the import" do
      wire_recipient(bic_code: nil)

      expect { run_task }.to change(Payee, :count).by(1)
      expect(event.payees.sole.legal_entity.payout_methods).to be_empty
    end
  end

  it "imports one payout method when two recipients hold identical details" do
    ach_recipient(email: "orpheus@hackclub.com", account_number: "111111111")
    ach_recipient(email: "orpheus@hackclub.com", account_number: "111111111")

    run_task

    expect(event.payees.sole.legal_entity.payout_methods.count).to eq(1)
  end

  it "keeps a name an older recipient carries when the newest was saved without one" do
    ach_recipient(email: "orpheus@hackclub.com", account_number: "111111111")
    travel_to(1.day.from_now) do
      create(:payment_recipient, event:, email: "orpheus@hackclub.com", payment_model: "AchTransfer", name: nil,
                                 routing_number: "021000021", account_number: "222222222", bank_name: "Chase")
    end

    run_task

    expect(event.payees.sole.display_name).to eq("Orpheus")
  end

  it "copies a check recipient's address across as a check payout method" do
    create(:payment_recipient, event:, email: "orpheus@hackclub.com", name: "Orpheus", payment_model: "IncreaseCheck",
                               address_line1: "8605 Santa Monica Blvd", address_city: "West Hollywood",
                               address_state: "CA", address_zip: "90069")

    run_task

    details = event.payees.sole.legal_entity.default_payout_method.details
    expect(details).to be_a(LegalEntity::PayoutMethod::Check)
    expect(details.address_postal_code).to eq("90069")
  end
end
