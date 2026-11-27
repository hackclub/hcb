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

  describe "fit_to_one_page" do
    before do
      # each stubbed body is "<page count> pages at <scale>"
      allow(PDF::Reader).to receive(:new) { |io| instance_double(PDF::Reader, page_count: io.string.to_i) }
    end

    def stub_scale(scale, pages)
      stub_request(:post, /browser-rendering/)
        .with(body: hash_including("pdfOptions" => hash_including("scale" => scale)))
        .to_return(status: 200, body: "#{pages} pages at #{scale}")
    end

    it "shrinks until the PDF fits on one page" do
      stub_scale(1, 2)
      fit = stub_scale(0.9, 1)
      smaller = stub_scale(0.8, 1)

      expect(described_class.pdf("<p>hi</p>", fit_to_one_page: true)).to eq("1 pages at 0.9")
      expect(fit).to have_been_requested
      expect(smaller).not_to have_been_requested
    end

    it "returns the smallest scale's PDF when nothing fits" do
      [1, 0.9, 0.8].each { |scale| stub_scale(scale, 2) }
      smallest = stub_scale(0.7, 2)

      expect(described_class.pdf("<p>hi</p>", fit_to_one_page: true)).to eq("2 pages at 0.7")
      expect(smallest).to have_been_requested
    end
  end

  it "scrubs HTML that arrives as raw bytes instead of failing to encode it as JSON" do
    stub = stub_request(:post, /browser-rendering/)
           .with(body: hash_including("html" => "<p>\uFFFD Shop</p>"))
           .to_return(status: 200, body: "%PDF-1.4")

    described_class.pdf("<p>\xA9 Shop</p>".b)
    expect(stub).to have_been_requested
  end

  it "raises on API errors instead of returning an error body as a PDF" do
    stub_request(:post, /browser-rendering/).to_return(status: 401)

    expect { described_class.pdf("<p>hi</p>") }.to raise_error(Faraday::UnauthorizedError)
  end
end
