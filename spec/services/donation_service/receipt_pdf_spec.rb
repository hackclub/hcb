# frozen_string_literal: true

require "rails_helper"

RSpec.describe DonationService::ReceiptPdf do
  it "generates a PDF without a controller request" do
    donation = build_stubbed(:donation)

    pdf = described_class.new(donation:).run

    expect(pdf).to start_with("%PDF-")
    expect(pdf).to include("%%EOF")
  end
end
