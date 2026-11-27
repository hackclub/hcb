# frozen_string_literal: true

require "rails_helper"

RSpec.describe DonationMailer do
  include DonationSupport

  describe "#donor_receipt" do
    let(:event) { create(:event, name: "Hack Club Assemble 2026 Hackathon", short_name: "Assemble") }
    let(:donation) do
      stub_donation_payment_intent_creation
      create(:donation, event:)
    end

    before { allow(CloudflareBrowserRun).to receive(:pdf).and_return("%PDF-1.4") }

    it "tells the donor how the charge shows up on their statement" do
      mail = described_class.with(donation:).donor_receipt

      expect(mail.html_part.body.decoded).to include("<strong>HCB* Assemble</strong>")
    end

    it "attaches a PDF receipt rendered from the donation" do
      mail = described_class.with(donation:).donor_receipt.message

      expect(CloudflareBrowserRun).to have_received(:pdf).with(a_string_including("Receipt ID: #{donation.public_id}"))
      expect(mail.attachments.size).to eq(1)
      expect(mail.attachments.first.filename).to eq("hack-club-donation-receipt-#{event.slug}-#{donation.public_id}.pdf")
      expect(mail.attachments.first.mime_type).to eq("application/pdf")
      expect(mail.html_part.body.decoded).to include("find attached a receipt")
    end

    it "still sends the email, without an attachment, when the PDF fails to render" do
      allow(CloudflareBrowserRun).to receive(:pdf).and_raise(Faraday::ServerError.new("Cloudflare is down"))
      allow(Rails.error).to receive(:report)

      mail = described_class.with(donation:).donor_receipt.message

      expect(Rails.error).to have_received(:report).with(an_instance_of(Faraday::ServerError), context: { donation_id: donation.id })
      expect(mail.attachments).to be_empty
      expect(mail.body.decoded).to include("consider this email a receipt")
    end
  end
end
