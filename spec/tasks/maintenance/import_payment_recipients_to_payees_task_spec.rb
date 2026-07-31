# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::ImportPaymentRecipientsToPayeesTask do
  let(:event) { create(:event) }

  def recipient(**attrs)
    create(:payment_recipient, event:, **attrs)
  end

  it "creates a payee from the recipient's name and email" do
    described_class.new.process(recipient(name: "Orpheus", email: "orpheus@hackclub.com"))

    payee = event.payees.sole
    expect(payee.display_name).to eq("Orpheus")
    expect(payee.email).to eq("orpheus@hackclub.com")
    expect(payee).to be_imported
    expect(payee.legal_entity).to be_nil
  end

  it "does not carry the legacy payout details over" do
    described_class.new.process(recipient(name: "Orpheus", email: "orpheus@hackclub.com",
                                          account_number: "123456789", routing_number: "110000000"))

    expect(event.payees.sole.legal_entity).to be_nil
  end

  it "skips recipients who already exist as a payee, ignoring email casing" do
    create(:payee, event:, legal_entity: nil, email: "Orpheus@hackclub.com")

    expect { described_class.new.process(recipient(name: "Orpheus", email: "orpheus@hackclub.com")) }
      .not_to(change { event.payees.count })
  end

  it "is idempotent across reruns" do
    record = recipient(name: "Orpheus", email: "orpheus@hackclub.com")

    described_class.new.process(record)
    expect { described_class.new.process(record) }.not_to(change { event.payees.count })
  end

  it "only collects recipients with both a name and an email" do
    complete = recipient(name: "Orpheus", email: "orpheus@hackclub.com")
    recipient(name: nil, email: "nameless@hackclub.com")

    expect(described_class.new.collection.to_a).to eq([complete])
  end

end
