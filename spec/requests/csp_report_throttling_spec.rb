# frozen_string_literal: true

require "rails_helper"

# Rack::Attack is disabled outside production, so these exercise the
# discriminators directly rather than driving real 429s.
RSpec.describe "CSP report throttling" do
  let(:ip) { "203.0.113.4" }
  let(:path) { Rails.configuration.constants[:csp_violation_report_path] }

  def request_for(path, method: "POST", content_length: nil)
    env = Rack::MockRequest.env_for(path, method:, "REMOTE_ADDR" => ip)
    env["CONTENT_LENGTH"] = content_length.to_s if content_length
    Rack::Attack::Request.new(env)
  end

  def discriminator(name) = Rack::Attack.throttles.fetch(name).block

  it "gives reports their own per-IP budget instead of the shared one" do
    report = request_for(path)

    expect(discriminator("req/ip").call(report)).to be_nil
    expect(discriminator("csp-reports/ip").call(report)).to eq(ip)
  end

  it "counts the trailing-slash variant, which also routes to the controller" do
    expect(discriminator("csp-reports/ip").call(request_for("#{path}/"))).to eq(ip)
  end

  # GET on this path falls through to events#show, so it must stay on the
  # shared budget or it would be the one unthrottled path in the app.
  it "keeps non-POST requests to the path on the shared budget" do
    get_request = request_for(path, method: "GET")

    expect(discriminator("req/ip").call(get_request)).to eq(ip)
    expect(discriminator("csp-reports/ip").call(get_request)).to be_nil
  end

  it "still counts ordinary pages against the shared budget" do
    expect(discriminator("req/ip").call(request_for("/branding", method: "GET"))).to eq(ip)
  end

  describe "the oversized-body blocklist" do
    def blocked?(request) = !!Rack::Attack.blocklists.fetch("oversized csp reports").block.call(request)

    it "rejects a body over the cap before Rails parses it" do
      expect(blocked?(request_for(path, content_length: 10_000_000))).to be true
    end

    it "lets a normal report through" do
      expect(blocked?(request_for(path, content_length: 200))).to be false
    end

    it "ignores other paths" do
      expect(blocked?(request_for("/branding", content_length: 10_000_000))).to be false
    end
  end
end
