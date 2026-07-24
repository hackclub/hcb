# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventService::LegacyPayoutMethod, type: :service do
  let(:event) do
    event = create(:event)
    create(:canonical_pending_transaction, amount_cents: 1_000_000, event:, fronted: true)
    event
  end

  def details_for(name: "Orpheus", email: "orpheus@hackclub.com")
    described_class.new(event, name:, email:).details
  end

  it "returns nil when the recipient has no legacy transfers" do
    expect(details_for).to be_nil
  end

  it "rebuilds an ACH payout method from the recipient's last ACH transfer" do
    create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com",
                          account_number: "123456789", routing_number: "110000000")

    details = details_for

    expect(details).to be_a(LegalEntity::PayoutMethod::AchTransfer)
    expect(details.account_number).to eq("123456789")
    expect(details.routing_number).to eq("110000000")
  end

  it "matches the recipient email case-insensitively" do
    create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com",
                          account_number: "123456789", routing_number: "110000000")

    expect(details_for(email: "ORPHEUS@hackclub.com")).to be_a(LegalEntity::PayoutMethod::AchTransfer)
  end

  it "ignores transfers from other events" do
    other_event = create(:event)
    create(:canonical_pending_transaction, amount_cents: 1_000_000, event: other_event, fronted: true)
    create(:ach_transfer, event: other_event, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com")

    expect(details_for).to be_nil
  end

  it "uses the recipient's most recent transfer" do
    create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com",
                          account_number: "111111111", routing_number: "110000000", created_at: 3.days.ago)
    create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com",
                          account_number: "222222222", routing_number: "110000000", created_at: 1.day.ago)

    expect(details_for.account_number).to eq("222222222")
  end
end
