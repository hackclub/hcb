# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionEngine::HashedTransactionService::PrimaryHash do
  let(:unique_bank_identifier) { "FSMAIN" }
  let(:date) { "2020-09-15" }
  let(:amount_cents) { 1_01 }
  let(:memo) { "A PAYMENT MEMO OF $1.01" }

  let(:service) do
    TransactionEngine::HashedTransactionService::PrimaryHash.new(
      unique_bank_identifier:,
      date:,
      amount_cents:,
      memo:
    )
  end

  it "hashes the combination" do
    expect(service.run[0]).to eql(9686534373925407058)
  end

  context "when memo just has extra padded spaces" do
    let(:memo) { " A PAYMENT MEMO OF $1.01 " }

    it "produces the same hash" do
      expect(service.run[0]).to eql(9686534373925407058)
    end
  end

  context "when memo has extra white space inside of it" do
    let(:memo) { "A  PAYMENT   MEMO OF $1.01" }

    it "produces the same hash" do
      expect(service.run[0]).to eql(9686534373925407058)
    end
  end

  context "when date changes" do
    let(:date) { "2020-09-16" }

    it "changes the hash" do
      expect(service.run[0]).not_to eql(9686534373925407058)
    end
  end

  context "when amount_cents changes" do
    let(:amount_cents) { 1_02 }

    it "changes the hash" do
      expect(service.run[0]).to eql(333912527157692946)
    end
  end

  context "when amount_cents type changes to string" do
    let(:amount_cents) { "101" }

    it "raises an error" do
      expect do
        service.run
      end.to raise_error(ArgumentError)
    end
  end

  context "when amount_cents is 0" do
    let(:amount_cents) { 0 }

    it "raises an error" do
      expect do
        service.run
      end.to raise_error(ArgumentError)
    end
  end

  context "when amount_cents is negative" do
    let(:amount_cents) { -2_02 }

    it "hashes" do
      expect(service.run[0]).to eql(8031277266291086396)
    end
  end

  context "when memo is not all uppercased" do
    let(:memo) { "downcased memo" }

    it "raises an error" do
      expect do
        service.run
      end.to raise_error(ArgumentError)
    end
  end

  context "when date is bad format" do
    let(:date) { "09/09/2020" }

    it "raises an error" do
      expect do
        service.run
      end.to raise_error(ArgumentError)
    end
  end

  context "when memo is nil" do
    let(:memo) { nil }

    it "hashes it as a blank memo" do
      expect(service.run[0]).to eql(described_class.new(unique_bank_identifier:, date:, amount_cents:, memo: "").run[0])
    end
  end
end
