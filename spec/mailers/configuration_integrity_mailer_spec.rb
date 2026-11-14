# frozen_string_literal: true

require "rails_helper"

RSpec.describe ConfigurationIntegrityMailer do
  describe "#taxbandits_leaking_tins" do
    it "goes to engineering, marked urgent" do
      mail = described_class.with(payee_ref: "tfm_dummy").taxbandits_leaking_tins

      expect(mail.to).to eq(["hcb-engr@hackclub.com"])
      expect(mail.subject).to eq("[URGENT] TaxBandits leaking full TINs")
      expect(mail.body.encoded).to include("tfm_dummy")
    end
  end

  describe "#check_failed" do
    it "names the check and why it couldn't run" do
      mail = described_class.with(check: "SomeCheckJob", reason: "The thing was missing.").check_failed

      expect(mail.to).to eq(["hcb-engr@hackclub.com"])
      expect(mail.subject).to eq("Configuration integrity check couldn't run: SomeCheckJob")
      expect(mail.body.encoded).to include("SomeCheckJob", "The thing was missing.")
    end
  end
end
