# frozen_string_literal: true

require "rails_helper"

RSpec.describe CloudflareBrowserRun do
  before do
    stub_const("ENV", ENV.to_h.merge("CLOUDFLARE__ACCOUNT_ID" => "acct", "CLOUDFLARE__BROWSER_RUN_API_TOKEN" => "tok"))
  end

  it "posts the HTML and returns the PDF bytes" do
    stub = stub_request(:post, "https://api.cloudflare.com/client/v4/accounts/acct/browser-rendering/pdf")
           .with(headers: { "Authorization" => "Bearer tok" }, body: hash_including("html" => "<p>hi</p>", "setJavaScriptEnabled" => false))
           .to_return(status: 200, body: "%PDF-1.4", headers: { "Content-Type" => "application/pdf" })

    expect(described_class.pdf("<p>hi</p>")).to eq("%PDF-1.4")
    expect(stub).to have_been_requested
  end

  it "raises on API errors instead of returning an error body as a PDF" do
    stub_request(:post, /browser-rendering/).to_return(status: 401)

    expect { described_class.pdf("<p>hi</p>") }.to raise_error(Faraday::UnauthorizedError)
  end
end
