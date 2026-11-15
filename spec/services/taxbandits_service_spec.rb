# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaxbanditsService do
  describe ".create_from_data" do
    let(:create_url) { "https://api.taxbandits.com/v1.7.3/WhCertificate/Create" }

    before do
      allow(described_class).to receive(:taxbandits_access_token).and_return("token")
      allow(Credentials).to receive(:fetch).and_call_original
      allow(Credentials).to receive(:fetch).with(:TAXBANDITS, :DOMAIN_ID).and_return("hcb.example")
      described_class.instance_variable_set(:@taxbandits_client, nil)
    end

    it "gives up well inside Rack::Timeout's 30s, so the caller sees the timeout" do
      sent_timeout = nil
      allow_any_instance_of(Faraday::Connection).to receive(:run_request).and_wrap_original do |original, *args, &configure|
        original.call(*args) do |req|
          configure.call(req)
          sent_timeout = req.options.timeout
        end
      end
      stub_request(:post, create_url).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      described_class.create_from_data({})

      expect(sent_timeout).to eq(20)
    end

    # Anything but a Faraday::ClientError (a 4xx) is an uncertain outcome to
    # Tax1099ImportService#submit!.
    it "raises a Faraday error other than a rejection when TaxBandits is too slow" do
      stub_request(:post, create_url).to_timeout

      expect { described_class.create_from_data({}) }.to(raise_error { |error|
        expect(error).to be_a(Faraday::Error)
        expect(error).not_to be_a(Faraday::ClientError)
      })
    end
  end
end
