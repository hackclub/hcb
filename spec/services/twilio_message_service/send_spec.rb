# frozen_string_literal: true

require "rails_helper"

RSpec.describe TwilioMessageService::Send do
  # `phone_number_verified` is reset whenever `phone_number` changes, so set it separately.
  let(:user) { create(:user, phone_number: "+18556254225").tap { |u| u.update!(phone_number_verified: true) } }
  let(:messages) { double("messages") }
  let(:client) { instance_double(Twilio::REST::Client, messages:, http_client: double("http_client", last_response: double("response", body: { "sid" => "SM1" }))) }

  before do
    allow(Credentials).to receive(:fetch).and_call_original
    allow(Credentials).to receive(:fetch).with(:TWILIO, :PHONE_NUMBER).and_return("+15555550100")
    allow(Twilio::REST::Client).to receive(:new).and_return(client)
    allow(messages).to receive(:create).and_return(double("message", sid: "SM1", account_sid: "AC1"))
  end

  it "texts the user and records the message" do
    sent = described_class.new(user, "hi").run!

    expect(messages).to have_received(:create).with(from: "+15555550100", to: user.phone_number, body: "hi")
    expect(sent).to have_attributes(to: user.phone_number, from: "+15555550100", body: "hi", twilio_sid: "SM1", twilio_account_sid: "AC1")
    expect(sent.outgoing_twilio_message).to have_attributes(hcb_code: nil, ledger_item: nil)
  end

  it "records the transaction the text is about" do
    hcb_code = create(:canonical_pending_transaction).local_hcb_code

    sent = described_class.new(user, "hi", hcb_code:, ledger_item: hcb_code.ledger_item).run!

    expect(sent.outgoing_twilio_message).to have_attributes(hcb_code:, ledger_item: hcb_code.ledger_item)
  end

  it "texts a given number when the user has none" do
    user.update!(phone_number: nil)

    described_class.new(user, "hi", phone_number: "+18005550100").run!

    expect(messages).to have_received(:create).with(hash_including(to: "+18005550100"))
  end

  it "does nothing without a number" do
    user.update!(phone_number: nil)

    expect(described_class.new(user, "hi").run!).to be_nil
    expect(messages).not_to have_received(:create)
  end
end
