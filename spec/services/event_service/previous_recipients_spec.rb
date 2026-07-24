# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventService::PreviousRecipients, type: :service do
  let(:event) { create(:event) }

  describe "#list" do
    it "surfaces recipients paid through legacy transfers" do
      create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com")

      result = described_class.new(event).list

      expect(result).to contain_exactly({ name: "Orpheus", email: "orpheus@hackclub.com" })
    end

    it "dedupes by email, keeping the most recently used name" do
      create(:ach_transfer, event:, recipient_name: "Old Name", recipient_email: "dupe@hackclub.com", created_at: 3.days.ago)
      create(:ach_transfer, event:, recipient_name: "New Name", recipient_email: "dupe@hackclub.com", created_at: 1.day.ago)

      result = described_class.new(event).list

      expect(result).to contain_exactly({ name: "New Name", email: "dupe@hackclub.com" })
    end

    it "excludes recipients who already exist as a payee" do
      create(:ach_transfer, event:, recipient_name: "Existing", recipient_email: "existing@hackclub.com")
      create(:payee, event:, email: "existing@hackclub.com")

      expect(described_class.new(event).list).to be_empty
    end

    it "matches payee emails case-insensitively" do
      create(:ach_transfer, event:, recipient_name: "Existing", recipient_email: "existing@hackclub.com")
      create(:payee, event:, email: "EXISTING@hackclub.com")

      expect(described_class.new(event).list).to be_empty
    end

    it "rejects recipients missing a name or email" do
      create(:payment_recipient, event:, name: "", email: "no-name@hackclub.com")

      expect(described_class.new(event).list).to be_empty
    end

    it "filters by the query against name and email" do
      create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com")
      create(:ach_transfer, event:, recipient_name: "Someone Else", recipient_email: "else@hackclub.com")

      result = described_class.new(event, query: "orph").list

      expect(result).to contain_exactly({ name: "Orpheus", email: "orpheus@hackclub.com" })
    end

    it "ignores recipients from other events" do
      other_event = create(:event)
      create(:ach_transfer, event: other_event, recipient_name: "Stranger", recipient_email: "stranger@hackclub.com")

      expect(described_class.new(event).list).to be_empty
    end

    it "caps the result at RESULT_LIMIT" do
      (described_class::RESULT_LIMIT + 2).times do |i|
        create(:ach_transfer, event:, recipient_name: "Recipient #{i}", recipient_email: "recipient#{i}@hackclub.com")
      end

      expect(described_class.new(event).list.size).to eq(described_class::RESULT_LIMIT)
    end
  end

  describe "#exists?" do
    it "is false when the event has no legacy transfers" do
      expect(described_class.new(event).exists?).to be(false)
    end

    it "is true when the event has an ACH transfer" do
      create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com")

      expect(described_class.new(event).exists?).to be(true)
    end

    it "is true when the event has a legacy payment recipient" do
      create(:payment_recipient, event:, name: "Orpheus", email: "orpheus@hackclub.com")

      expect(described_class.new(event).exists?).to be(true)
    end
  end
end
