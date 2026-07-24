# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventService::LegacyPayoutMethod, type: :service do
  let(:event) do
    event = create(:event)
    create(:canonical_pending_transaction, amount_cents: 1_000_000, event:, fronted: true)
    event
  end

  def details_for(email: "orpheus@hackclub.com")
    described_class.new(event, email:).details
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

  it "uses the recipient's most recent transfer of a given method" do
    create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com",
                          account_number: "111111111", routing_number: "110000000", created_at: 3.days.ago)
    create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com",
                          account_number: "222222222", routing_number: "110000000", created_at: 1.day.ago)

    expect(details_for.account_number).to eq("222222222")
  end

  describe "#details_list" do
    def list_for(email: "orpheus@hackclub.com")
      described_class.new(event, email:).details_list
    end

    it "is empty when the recipient has no legacy transfers" do
      expect(list_for).to eq([])
    end

    it "returns one method per type the recipient was paid with, most recent first" do
      create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com",
                            created_at: 3.days.ago)
      IncreaseCheck.create!(event:, user: create(:user), amount: 5_00, memo: "Potions", payment_for: "Potions",
                            recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com",
                            address_line1: "8557 Villa La Jolla Dr", address_line2: "", address_city: "La Jolla",
                            address_state: "CA", address_zip: "92037", created_at: 1.day.ago)

      list = list_for

      expect(list.map(&:class)).to eq([LegalEntity::PayoutMethod::Check, LegalEntity::PayoutMethod::AchTransfer])
    end

    it "matches on email even when the recipient name differs across transfers" do
      create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com",
                            created_at: 3.days.ago)
      IncreaseCheck.create!(event:, user: create(:user), amount: 5_00, memo: "Potions", payment_for: "Potions",
                            recipient_name: "Orpheus the Dinosaur", recipient_email: "orpheus@hackclub.com",
                            address_line1: "8557 Villa La Jolla Dr", address_line2: "", address_city: "La Jolla",
                            address_state: "CA", address_zip: "92037", created_at: 1.day.ago)

      expect(list_for.map(&:class)).to contain_exactly(
        LegalEntity::PayoutMethod::Check, LegalEntity::PayoutMethod::AchTransfer
      )
    end

    it "collapses multiple transfers of the same type into one method" do
      create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com")
      create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com")

      expect(list_for.map(&:class)).to eq([LegalEntity::PayoutMethod::AchTransfer])
    end
  end
end
