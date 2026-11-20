# frozen_string_literal: true

require "rails_helper"

RSpec.describe DonationService::ReceiptPdf do
  before do
    stub_const("ENV", ENV.to_h.merge("CLOUDFLARE__ACCOUNT_ID" => "acct", "CLOUDFLARE__BROWSER_RUN_API_TOKEN" => "tok"))
  end

  it "generates a PDF without a controller request" do
    donation = build_stubbed(:donation)
    stub_request(:post, "https://api.cloudflare.com/client/v4/accounts/acct/browser-rendering/pdf")
      .with(body: hash_including("html" => including(donation.public_id, "data:image/png;base64,", "By the students, for the students.")))
      .to_return(status: 200, body: "%PDF-1.4\n%%EOF", headers: { "Content-Type" => "application/pdf" })

    pdf = described_class.new(donation:).run

    expect(pdf).to eq("%PDF-1.4\n%%EOF")
  end
end
