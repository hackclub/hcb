# frozen_string_literal: true

require "rails_helper"

RSpec.describe WirePolicy, type: :policy do
  before do
    stub_request(:get, /api\.column\.com\/institutions\/.*/)
      .to_return(status: 200, body: '{"country_code": "DE"}', headers: { "Content-Type" => "application/json" })
  end

  let(:admin) { create(:user, :make_admin) }
  let(:non_admin) { create(:user) }
  let(:event) { create(:event, :with_positive_balance) }

  describe "#edit?" do
    context "when wire is pending" do
      let(:wire) { create(:wire, :pending, event: event, user: admin) }

      it "allows admin to edit" do
        expect(described_class.new(admin, wire).edit?).to eq(true)
      end

      it "does not allow non-admin to edit" do
        expect(described_class.new(non_admin, wire).edit?).to eq(false)
      end
    end

    context "when wire is approved" do
      let(:wire) { create(:wire, :approved, event: event, user: admin) }

      it "does not allow admin to edit" do
        expect(described_class.new(admin, wire).edit?).to eq(false)
      end
    end

    context "when wire is deposited" do
      let(:wire) { create(:wire, :deposited, event: event, user: admin) }

      it "does not allow admin to edit" do
        expect(described_class.new(admin, wire).edit?).to eq(false)
      end
    end
  end

  describe "#update?" do
    context "when wire is pending" do
      let(:wire) { create(:wire, :pending, event: event, user: admin) }

      it "allows admin to update" do
        expect(described_class.new(admin, wire).update?).to eq(true)
      end

      it "does not allow non-admin to update" do
        expect(described_class.new(non_admin, wire).update?).to eq(false)
      end
    end

    context "when wire is approved" do
      let(:wire) { create(:wire, :approved, event: event, user: admin) }

      it "does not allow admin to update" do
        expect(described_class.new(admin, wire).update?).to eq(false)
      end
    end

    context "when wire is deposited" do
      let(:wire) { create(:wire, :deposited, event: event, user: admin) }

      it "does not allow admin to update" do
        expect(described_class.new(admin, wire).update?).to eq(false)
      end
    end
  end
end
