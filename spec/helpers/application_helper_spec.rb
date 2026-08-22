# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#external_url" do
    it "passes through http(s) URLs" do
      expect(helper.external_url("https://dashboard.stripe.com/invoices/in_123")).to eq("https://dashboard.stripe.com/invoices/in_123")
      expect(helper.external_url("http://example.com")).to eq("http://example.com")
    end

    it "escapes the URL so it's safe to use as an href" do
      expect(helper.external_url("https://example.com/?a=1&b=2")).to eq("https://example.com/?a=1&amp;b=2")
    end

    it "refuses anything that isn't a plain http(s) URL" do
      expect(helper.external_url("javascript:alert(1)")).to be_nil
      expect(helper.external_url("data:text/html,<script>alert(1)</script>")).to be_nil
      expect(helper.external_url("/admin/events")).to be_nil
      expect(helper.external_url("http://exa mple.com")).to be_nil
      expect(helper.external_url(nil)).to be_nil
      expect(helper.external_url("")).to be_nil
    end
  end
end
