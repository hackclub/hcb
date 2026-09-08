# frozen_string_literal: true

require "rails_helper"

RSpec.describe Rack::Attack, type: :request do
  # Rack::Attack is only enabled in production, and the test cache is a
  # null_store, which would silently never increment a counter.
  around do |example|
    enabled = Rack::Attack.enabled
    store = Rack::Attack.cache.store
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    begin
      example.run
    ensure
      Rack::Attack.enabled = enabled
      Rack::Attack.cache.store = store
    end
  end

  def request_for(path, method: "GET", session_token: nil, content_length: nil)
    env = Rack::MockRequest.env_for(path, method:, "REMOTE_ADDR" => "203.0.113.7")
    env["HTTP_COOKIE"] = "session_token=#{session_token}" if session_token
    env["CONTENT_LENGTH"] = content_length.to_s if content_length
    Rack::Attack::Request.new(env)
  end

  def discriminator(throttle, path, **)
    Rack::Attack.throttles.fetch(throttle).block.call(request_for(path, **))
  end

  def blocklisted?(blocklist, path, **)
    !!Rack::Attack.blocklists.fetch(blocklist).block.call(request_for(path, **))
  end

  describe "transparency/ledger/ip" do
    it "throttles anonymous reads of any organization's transactions" do
      [
        "/an-organization/transactions",
        "/an-organization/transactions_list",
        "/an-organization/ledger",
        "/some-other-org/transactions_list",
        # The format suffix reaches the same action at the same cost.
        "/an-organization/transactions_list.json",
        "/an-organization/transactions.csv"
      ].each do |path|
        expect(discriminator("transparency/ledger/ip", path)).to eq("203.0.113.7"), "expected #{path} to be throttled"
      end
    end

    it "ignores requests that carry a session_token cookie" do
      expect(discriminator("transparency/ledger/ip", "/an-organization/transactions_list", session_token: "abc123")).to be_nil
    end

    it "ignores paths outside the ledger surface" do
      [
        "/an-organization",
        "/an-organization/team",
        "/an-organization/transactions_list/extra",
        "/admin/ledger",
        "/admin/ledger_items",
        "/storage/representations/redirect/abc/def"
      ].each do |path|
        expect(discriminator("transparency/ledger/ip", path)).to be_nil, "expected #{path} not to be throttled"
      end
    end

    it "responds with 429 once an anonymous client passes the limit" do
      limit = Rack::Attack.throttles.fetch("transparency/ledger/ip").limit

      # Counters bucket by `Time.now.to_i / period`, so a minute boundary
      # mid-loop would reset the count and lose the throttle.
      freeze_time do
        limit.times { get "/an-organization/transactions_list" }
        expect(response.body).not_to eq("Retry later\n")

        get "/an-organization/transactions_list"
        expect(response).to have_http_status(:too_many_requests)
        expect(response.body).to eq("Retry later\n")
      end
    end
  end

  describe "ledger/ip" do
    # A forged `session_token` escapes the throttle above, since the cookie can't
    # be verified at this layer. This is what stops that meaning unlimited access.
    it "applies whether or not a session_token cookie is present" do
      expect(discriminator("ledger/ip", "/an-organization/transactions_list")).to eq("203.0.113.7")
      expect(discriminator("ledger/ip", "/an-organization/transactions_list", session_token: "forged")).to eq("203.0.113.7")
    end

    it "responds with 429 to a client sending an unverified session_token" do
      limit = Rack::Attack.throttles.fetch("ledger/ip").limit
      forged = { "HTTP_COOKIE" => "session_token=forged" }

      freeze_time do
        limit.times { get "/an-organization/transactions_list", headers: forged }
        expect(response.body).not_to eq("Retry later\n")

        get "/an-organization/transactions_list", headers: forged
        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end

  describe "csp-reports/ip" do
    let(:path) { Rails.configuration.constants[:csp_violation_report_path] }

    it "gives reports their own budget instead of the shared one" do
      expect(discriminator("req/ip", path, method: "POST")).to be_nil
      expect(discriminator("csp-reports/ip", path, method: "POST")).to eq("203.0.113.7")
    end

    it "covers the path variants that also route to the controller" do
      ["#{path}/", "#{path}.json"].each do |variant|
        expect(discriminator("csp-reports/ip", variant, method: "POST")).to eq("203.0.113.7"), "expected #{variant} to be throttled"
      end
    end

    # Rails routes a doubled slash to the same action. MockRequest.env_for reads
    # "//x" as protocol-relative, so set the path Rack would actually see.
    it "covers a doubled leading slash" do
      request = request_for(path, method: "POST")
      request.env["PATH_INFO"] = "/#{path}"

      expect(Rack::Attack.throttles.fetch("csp-reports/ip").block.call(request)).to eq("203.0.113.7")
    end

    # GET on this path falls through to events#show, so it has to stay on the
    # shared budget or it would be the one unthrottled path in the app.
    it "leaves non-POST requests to the path on the shared budget" do
      expect(discriminator("req/ip", path)).to eq("203.0.113.7")
      expect(discriminator("csp-reports/ip", path)).to be_nil
    end
  end

  describe "oversized csp reports" do
    let(:path) { Rails.configuration.constants[:csp_violation_report_path] }
    let(:cap) { Rails.configuration.constants[:csp_violation_report_max_bytes] }

    it "rejects a body over the cap before Rails buffers it" do
      expect(blocklisted?("oversized csp reports", path, method: "POST", content_length: cap + 1)).to be true
    end

    it "lets a normal report through" do
      expect(blocklisted?("oversized csp reports", path, method: "POST", content_length: cap)).to be false
    end

    it "ignores other paths" do
      expect(blocklisted?("oversized csp reports", "/branding", method: "POST", content_length: cap + 1)).to be false
    end

    it "is not bypassed by a doubled slash" do
      request = request_for(path, method: "POST", content_length: cap + 1)
      request.env["PATH_INFO"] = "/#{path}"

      expect(Rack::Attack.blocklists.fetch("oversized csp reports").block.call(request)).to be_truthy
    end
  end
end
