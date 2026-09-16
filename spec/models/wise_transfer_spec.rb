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

  describe ".fit_quote_to_maximum" do
    let(:maximum) { Money.from_cents(1_000, "USD") }

    def quote_for(amount, maximum_target_cents: 900)
      with_fees = amount.cents <= maximum_target_cents ? maximum : maximum + Money.from_cents(1, "USD")
      {
        initial_local_amount: amount,
        without_fees_usd_amount: with_fees - Money.from_cents(100, "USD"),
        with_fees_usd_amount: with_fees,
        fees_usd_amount: Money.from_cents(100, "USD")
      }
    end

    it "returns the greatest target-currency minor unit that fits exactly at the cap" do
      allow(described_class).to receive(:convert_usd_to_local).and_return(Money.from_cents(1_000, "GBP"))
      allow(described_class).to receive(:generate_detailed_quote) { |amount| quote_for(amount) }

      result = described_class.fit_quote_to_maximum(maximum, "GBP")

      expect(result[:initial_local_amount]).to eq(Money.from_cents(900, "GBP"))
      expect(result[:with_fees_usd_amount]).to eq(maximum)
      expect(described_class).to have_received(:generate_detailed_quote).with(Money.from_cents(901, "GBP"))
    end

    it "searches in the target currency's smallest units" do
      allow(described_class).to receive(:convert_usd_to_local).and_return(Money.from_cents(10_000, "KWD"))
      allow(described_class).to receive(:generate_detailed_quote) { |amount| quote_for(amount, maximum_target_cents: 9_123) }

      result = described_class.fit_quote_to_maximum(maximum, "KWD")

      expect(result[:initial_local_amount].cents).to eq(9_123)
      expect(result[:initial_local_amount].amount).to eq(BigDecimal("9.123"))
    end

    it "propagates Wise quote failures" do
      allow(described_class).to receive(:convert_usd_to_local).and_raise(Faraday::ConnectionFailed, "unavailable")

      expect { described_class.fit_quote_to_maximum(maximum, "GBP") }
        .to raise_error(Faraday::ConnectionFailed)
    end
  end

  describe ".generate_detailed_quote" do
    it "rounds the ACH-adjusted fee-inclusive amount to USD cents" do
      response = instance_double(Faraday::Response, body: {
                                   "paymentOptions" => [{
                                     "sourceAmount" => 100,
                                     "price"        => { "items" => [
                                       { "type" => "PAYIN", "value" => { "amount" => 1 } },
                                       { "type" => "TRANSFER", "value" => { "amount" => 2 } }
                                     ]
}
                                   }]
                                 })
      connection = instance_double(Faraday::Connection)
      allow(connection).to receive(:post).and_return(response)
      allow(described_class).to receive(:quote_connection).and_return(connection)

      result = described_class.generate_detailed_quote(Money.from_amount(80, "GBP"))

      expect(result[:with_fees_usd_amount]).to eq(Money.from_amount(99.17, "USD"))
      expect(result[:fees_usd_amount]).to eq(Money.from_amount(2.17, "USD"))
    end
  end
end
