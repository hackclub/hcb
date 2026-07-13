# frozen_string_literal: true

require "rails_helper"

RSpec.describe HackClub do
  describe ".office_ips" do
    it "parses the OFFICE_IP credential into IPAddr objects" do
      allow(Credentials).to receive(:fetch).with(:OFFICE_IP).and_return("1.2.3.4, 5.6.7.8/24 ")

      expect(described_class.office_ips).to eq([IPAddr.new("1.2.3.4"), IPAddr.new("5.6.7.8/24")])
    end

    it "reports and skips malformed entries" do
      allow(Credentials).to receive(:fetch).with(:OFFICE_IP).and_return("1.2.3.4, not-an-ip")

      expect(Rails.error).to receive(:report).with(
        an_instance_of(IPAddr::InvalidAddressError), context: { office_ip: "not-an-ip" }
      )

      expect(described_class.office_ips).to eq([IPAddr.new("1.2.3.4")])
    end

    it "parses once, reporting a malformed entry only once across repeated calls" do
      allow(Credentials).to receive(:fetch).with(:OFFICE_IP).and_return("not-an-ip")

      expect(Rails.error).to receive(:report).once

      3.times { described_class.office_ips }
    end

    it "returns an empty array when the credential is unset" do
      allow(Credentials).to receive(:fetch).with(:OFFICE_IP).and_return(nil)

      expect(described_class.office_ips).to eq([])
    end

    it "never returns nil when a concurrent parse has published the source key but not the list" do
      # Simulate the interleaving where one thread has recorded the source key
      # but has not yet published the parsed list. A reader in this window must
      # re-parse rather than return the not-yet-populated nil (which would crash
      # the Rack::Attack safelist on `nil.any?`).
      allow(Credentials).to receive(:fetch).with(:OFFICE_IP).and_return("1.2.3.4")
      described_class.instance_variable_set(:@office_ips_source, "1.2.3.4")
      described_class.instance_variable_set(:@office_ips, nil)

      expect(described_class.office_ips).to eq([IPAddr.new("1.2.3.4")])
    end

    it "rejects a default-route entry that would safelist the entire internet" do
      allow(Credentials).to receive(:fetch).with(:OFFICE_IP).and_return("0.0.0.0/0")
      described_class.instance_variable_set(:@office_ips_source, nil)

      office_ips = described_class.office_ips

      expect(office_ips).to eq([])
      expect(office_ips.any? { |ip| ip.include?("8.8.8.8") }).to be(false)
    end

    it "rejects an IPv6 default-route entry" do
      allow(Credentials).to receive(:fetch).with(:OFFICE_IP).and_return("::/0")
      described_class.instance_variable_set(:@office_ips_source, nil)

      expect(described_class.office_ips).to eq([])
    end
  end
end
