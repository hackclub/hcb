# frozen_string_literal: true

require "rails_helper"

RSpec.describe Disbursement::Base, type: :model do
  let(:disbursement) { create(:disbursement) }

  describe "#initialize" do
    it "accepts a Disbursement" do
      wrapper = described_class.new(disbursement)
      expect(wrapper.disbursement).to eq(disbursement)
    end

    it "raises ArgumentError for non-Disbursement" do
      expect { described_class.new("not a disbursement") }.to raise_error(ArgumentError, "Expected Disbursement")
    end
  end

  describe "#disbursement" do
    it "returns the wrapped disbursement" do
      wrapper = described_class.new(disbursement)
      expect(wrapper.disbursement).to eq(disbursement)
    end
  end

  describe "delegation" do
    let(:wrapper) { described_class.new(disbursement) }

    it "delegates id to disbursement" do
      expect(wrapper.id).to eq(disbursement.id)
    end

    it "delegates amount to disbursement" do
      expect(wrapper.amount).to eq(disbursement.amount)
    end

    it "delegates name to disbursement" do
      expect(wrapper.name).to eq(disbursement.name)
    end

    it "delegates source_event to disbursement" do
      expect(wrapper.source_event).to eq(disbursement.source_event)
    end

    it "delegates destination_event to disbursement" do
      expect(wrapper.destination_event).to eq(disbursement.destination_event)
    end

    it "delegates fulfilled? to disbursement" do
      expect(wrapper.fulfilled?).to eq(disbursement.fulfilled?)
    end

    it "delegates reviewing? to disbursement" do
      expect(wrapper.reviewing?).to eq(disbursement.reviewing?)
    end
  end

  describe "abstract methods" do
    let(:wrapper) { described_class.new(disbursement) }

    it "raises NotImplementedError for hcb_code" do
      expect { wrapper.hcb_code }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for event" do
      expect { wrapper.event }.to raise_error(NotImplementedError)
    end
  end
end
