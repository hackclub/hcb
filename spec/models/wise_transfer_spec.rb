# frozen_string_literal: true

require "rails_helper"

RSpec.describe WiseTransfer do
  def build_instance(wise_id:)
    described_class.new(
      wise_id:,
      # Everything below shouldn't be required but we have validation code that
      # assumes these attributes are present.
      event: build(:event),
      recipient_country: :CA
    )
  end

  describe "#wise_id" do
    it "is optional" do
      instance = build_instance(wise_id: nil)
      instance.validate
      expect(instance.errors[:wise_id]).to be_empty
    end

    it "must be a number" do
      instance = build_instance(wise_id: "NOPE")
      instance.validate
      expect(instance.errors[:wise_id]).to eq(["is not a valid Wise ID"])

      instance.wise_id = "\t1234567890 "
      instance.validate
      expect(instance.errors[:wise_id]).to be_empty
      expect(instance.wise_id).to eq("1234567890")
    end

    it "is automatically normalized from a URL" do
      instance = build_instance(wise_id: " https://wise.com/transactions/activities/by-resource/TRANSFER/1234567890\n")
      instance.validate
      expect(instance.errors[:wise_id]).to be_empty
      expect(instance.wise_id).to eq("1234567890")

      instance.wise_id = "https://wise.com/success/transfer/0987654321"
      instance.validate
      expect(instance.errors[:wise_id]).to be_empty
      expect(instance.wise_id).to eq("0987654321")
    end
  end
end
