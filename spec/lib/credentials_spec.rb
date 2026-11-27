# frozen_string_literal: true

require "rails_helper"

RSpec.describe Credentials::Doppler do
  describe ".fetch_secrets" do
    let(:response) { Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized") }

    around do |example|
      keys = %w[http_proxy HTTP_PROXY https_proxy HTTPS_PROXY no_proxy NO_PROXY]
      saved = keys.index_with { |k| ENV.fetch(k, nil) }
      begin
        keys.each { |k| ENV.delete(k) }
        example.run
      ensure
        saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
      end
    end

    it "routes the request through https_proxy" do
      ENV["https_proxy"] = "http://user:pass@proxy.internal:8080"

      expect(Net::HTTP).to receive(:start)
        .with("api.doppler.com", 443, "proxy.internal", 8080, "user", "pass", use_ssl: true)
        .and_return(response)

      described_class.fetch_secrets
    end

    it "decodes percent-encoded proxy credentials" do
      ENV["https_proxy"] = "http://us%40er:p%3Ass%2Fword@proxy.internal:8080"

      expect(Net::HTTP).to receive(:start)
        .with("api.doppler.com", 443, "proxy.internal", 8080, "us@er", "p:ss/word", use_ssl: true)
        .and_return(response)

      described_class.fetch_secrets
    end

    it "connects directly when no proxy is configured" do
      expect(Net::HTTP).to receive(:start)
        .with("api.doppler.com", 443, nil, nil, nil, nil, use_ssl: true)
        .and_return(response)

      described_class.fetch_secrets
    end

    it "connects directly when api.doppler.com is in no_proxy" do
      ENV["https_proxy"] = "http://proxy.internal:8080"
      ENV["no_proxy"] = "localhost,api.doppler.com"

      expect(Net::HTTP).to receive(:start)
        .with("api.doppler.com", 443, nil, nil, nil, nil, use_ssl: true)
        .and_return(response)

      described_class.fetch_secrets
    end
  end
end
