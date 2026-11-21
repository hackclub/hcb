# frozen_string_literal: true

require "rails_helper"

# The /for/ai-safety marketing landing page. Parsed with Nokogiri and compared as text,
# because ERB escapes apostrophes in the raw HTML.
RSpec.describe "AI safety landing page", type: :request do
  def page
    Nokogiri::HTML(response.body)
  end

  def canonical_url
    ai_safety_url(host: Rails.application.routes.default_url_options[:host], protocol: "https")
  end

  describe "GET /for/ai-safety" do
    it "renders for signed-out visitors with the H1, indexable" do
      get ai_safety_path

      expect(response).to have_http_status(:ok)
      expect(page.at_css("h1").text.squish).to eq("Fiscal sponsorship for AI safety teams")
      expect(response.headers["X-Robots-Tag"]).to be_nil
      expect(page.at_css("title").text.scan(" – HCB").size).to eq(1)
    end

    it "shows the dashboard link to signed-in users" do
      user = create(:user, verified: true)
      session = create(:user_session, user:, verified: true, expiration_at: 1.hour.from_now)
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)

      get ai_safety_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dashboard")
    end

    # The canonical URL comes from the configured host, never the query string or Host header.
    it "has a canonical URL without the query string" do
      get ai_safety_path(ref: "x", audience: "funder")

      href = page.at_css("link[rel=canonical]")["href"]
      expect(href).to eq(canonical_url)
      expect(href).not_to include("?")
    end

    # Answer engines read the JSON-LD; it must say exactly what the page says.
    it "emits FAQ JSON-LD matching the visible answers, in order" do
      get ai_safety_path

      graph = JSON.parse(page.at_css("script[type='application/ld+json']").text)["@graph"]
      faq = graph.find { |node| node["@type"] == "FAQPage" }
      expected = helper_faqs

      expect(faq["mainEntity"].map { |q| q["name"] }).to eq(expected.map { |f| f[:q] })
      expect(page.css(".mk-faq__a").map { |a| a.text.squish }).to eq(expected.map { |f| f[:a] })
      expect(graph.find { |node| node["@type"] == "WebPage" }["@id"]).to eq(canonical_url)
    end

    it "puts the team email in the hero, shows the example ledger, and never mentions PayPal" do
      get ai_safety_path

      expect(page.at_css(".mk-ais__head a[href='mailto:aisafety@hackclub.com']")).to be_present
      expect(page.text).to include("+$850,000.00", "−$48,150.00")
      expect(response.body).not_to include("PayPal")
    end

    it "presets the audience radio from an allowlisted param only" do
      get ai_safety_path(audience: "funder")
      expect(page.css("input[name='ai_safety_inquiry[audience]'][checked]").map { |i| i["value"] }).to eq(["funder"])

      get ai_safety_path(audience: "admin")
      expect(page.css("input[name='ai_safety_inquiry[audience]'][checked]").map { |i| i["value"] }).to eq(["team"])
    end

    it "keeps a clean ref and drops anything else" do
      get ai_safety_path(ref: "Newsletter_1")
      expect(page.at_css("input[name='ai_safety_inquiry[ref]']")["value"]).to eq("newsletter_1")

      ["<script>", "a" * 65].each do |ref|
        get ai_safety_path(ref:)
        expect(page.at_css("input[name='ai_safety_inquiry[ref]']")["value"]).to be_blank
      end
    end

    it "marks only AI safety as the current page in the nav" do
      get ai_safety_path

      current = page.css("a[aria-current=page]")
      expect(current.map { |a| a.text.squish }).to eq(["AI safety"])
    end

    it "links to the grantmakers section, the due-diligence preset, and the funders page" do
      get ai_safety_path

      hrefs = page.css("a").map { |a| a["href"] }
      expect(hrefs).to include("#grantmakers", "/for/ai-safety?audience=funder#talk-to-us", "/for/funders")
      expect(page.at_css("#grantmakers")).to be_present
    end

    it "has no em dashes or exclamation marks in the page copy" do
      get ai_safety_path

      main = page.at_css("main")
      main.css("style, script").each(&:remove) # the honeypot's inline style uses !important
      text = main.text
      expect(text).not_to include("\u2014")
      expect(text).not_to include("!")
    end
  end

  def helper_faqs
    # Same live figures the page interpolates (the test cache is a null store, so they're recomputed).
    MarketingController.helpers.ai_safety_faqs(stats: MarketingController.new.send(:funder_stats))
  end
end
