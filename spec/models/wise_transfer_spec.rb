# frozen_string_literal: true

require "rails_helper"

RSpec.describe WiseTransfer do
  def build_instance(**attrs)
    described_class.new(
      **attrs,
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

    it "is required if the wise transfer is marked as sent or deposited" do
      ["sent", "deposited"].each do |aasm_state|
        instance = build_instance(wise_id: nil, aasm_state:)
        instance.validate

        expect(instance.errors[:wise_id]).to(
          eq(["can't be blank"]),
          "wise transfer with aasm state #{aasm_state.inspect} should require wise_id"
        )
      end
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

  describe "#wise_recipient_id" do
    it "is optional" do
      instance = build_instance(wise_recipient_id: nil)
      instance.validate
      expect(instance.errors[:wise_recipient_id]).to be_empty
    end

    it "is required if the wise transfer is marked as sent or deposited" do
      ["sent", "deposited"].each do |aasm_state|
        instance = build_instance(wise_recipient_id: nil, aasm_state:)
        instance.validate

        expect(instance.errors[:wise_recipient_id]).to(
          eq(["can't be blank"]),
          "wise transfer with aasm state #{aasm_state.inspect} should require wise_recipient_id"
        )
      end
    end

    it "must be a UUID-like string" do
      instance = build_instance(wise_recipient_id: "NOPE")
      instance.validate
      expect(instance.errors[:wise_recipient_id]).to eq(["is not a valid Wise recipient ID"])

      instance.wise_recipient_id = "\t3e219880-5f3e-4230-8a5a-9c8c25af26bb "
      instance.validate
      expect(instance.errors[:wise_recipient_id]).to be_empty
      expect(instance.wise_recipient_id).to eq("3e219880-5f3e-4230-8a5a-9c8c25af26bb")
    end

    it "is automatically normalized from a URL" do
      instance = build_instance(wise_recipient_id: "https://wise.com/recipients/3e219880-5f3e-4230-8a5a-9c8c25af26bb?list=ALL")
      instance.validate
      expect(instance.errors[:wise_recipient_id]).to be_empty
      expect(instance.wise_recipient_id).to eq("3e219880-5f3e-4230-8a5a-9c8c25af26bb")
    end
  end
end
