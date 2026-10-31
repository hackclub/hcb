# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wire, type: :model do
  describe "#beneficiary_phone" do
    # Column rejects E.164 and space-separated numbers; it wants `+CC-...`.
    def beneficiary_phone_for(country, phone)
      Wire.new(recipient_country: country, recipient_information: { "phone" => phone }).send(:beneficiary_phone)
    end

    it "formats an E.164 number with dashes after the country code" do
      expect(beneficiary_phone_for("BR", "+5521987654321")).to eq("+55-21-98765-4321")
    end

    it "adds the recipient country's calling code to a national number" do
      expect(beneficiary_phone_for("IN", "98765 43210")).to eq("+91-98765-43210")
    end

    it "passes through a number it can't parse" do
      expect(beneficiary_phone_for("IN", "not a phone")).to eq("not a phone")
    end

    it "is nil when no phone was collected" do
      expect(beneficiary_phone_for("IN", nil)).to be_nil
    end
  end
end
