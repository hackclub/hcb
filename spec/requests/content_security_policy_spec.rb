# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Content Security Policy", type: :request do
  let(:event) { create(:event) }

  before do
    allow(TurnstileService).to receive_messages(site_key: "0x0000site", secret_key: "0x0000secret")
  end

  # Falls back to the enforced header so these survive flipping CSP_ENFORCE.
  def policy
    response.headers["Content-Security-Policy-Report-Only"] ||
      response.headers["Content-Security-Policy"]
  end

  def sources_for(directive)
    policy[/(?:\A|; )#{directive} ([^;]*)/, 1].to_s.split
  end

  it "ships report-only, so nothing is blocked until CSP_ENFORCE=true" do
    get root_path

    expect(response.headers["Content-Security-Policy-Report-Only"]).to be_present
    expect(response.headers["Content-Security-Policy"]).to be_nil
  end

  it "points violations at the endpoint that logs them" do
    get root_path

    expect(policy).to include("report-uri #{Rails.configuration.constants[:csp_violation_report_path]}")
  end

  it "allows the asset host, which serves every script and stylesheet in production" do
    get root_path

    asset_host = ENV.fetch("ASSET_HOST")
    %w[script-src style-src font-src connect-src].each do |directive|
      expect(sources_for(directive)).to include(asset_host), "#{directive} is missing the asset host"
    end
  end

  it "allows the S3 bucket, which direct uploads PUT to and receipt iframes redirect to" do
    get root_path

    bucket = ENV.fetch("S3__BUCKET")
    global = "https://#{bucket}.s3.amazonaws.com"
    regional = "https://#{bucket}.s3.#{ENV.fetch('S3__REGION')}.amazonaws.com"

    expect(sources_for("connect-src")).to include(global, regional)
    expect(sources_for("frame-src")).to include(global, regional)
  end

  it "allows the third parties the app actually loads" do
    get root_path

    expect(sources_for("script-src")).to include(
      "https://js.stripe.com", "https://cdn.plaid.com", "https://challenges.cloudflare.com",
      "https://edge.fullstory.com", "https://beacon-v2.helpscout.net"
    )
    expect(sources_for("connect-src")).to include(
      "https://api.stripe.com", "https://*.fullstory.com", "https://docuseal.co"
    )
    expect(sources_for("frame-src")).to include(
      "https://hooks.stripe.com", "https://docuseal.co", "https://links.taxbandits.io"
    )
  end

  describe "donation pages, which orgs embed in their own sites" do
    # frame-ancestors is ignored in a report-only policy, so X-Frame-Options is
    # what would actually block the embed. It has to be dropped independently.
    it "drops X-Frame-Options so the page can be framed" do
      get start_donation_donations_path(event.slug)

      expect(response.headers["X-Frame-Options"]).to be_nil
    end

    it "widens frame-ancestors to *" do
      get start_donation_donations_path(event.slug)

      expect(policy).to include("frame-ancestors *")
    end

    it "leaves donation actions that aren't embedded alone" do
      get qr_code_donations_path(event.slug, format: :svg)

      expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
    end
  end

  it "keeps X-Frame-Options and frame-ancestors 'self' everywhere else" do
    get root_path

    expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
    expect(policy).to include("frame-ancestors 'self'")
  end
end
