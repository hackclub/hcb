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

  def discriminator(throttle, path, session_token: nil)
    env = Rack::MockRequest.env_for(path, "REMOTE_ADDR" => "203.0.113.7")
    env["HTTP_COOKIE"] = "session_token=#{session_token}" if session_token
    Rack::Attack.throttles.fetch(throttle).block.call(Rack::Attack::Request.new(env))
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
end
