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

  describe "viewing a wire" do
    let(:wire) { create(:wire, event:, user: admin) }
    let(:reader) { create(:user).tap { |user| create(:organizer_position, event:, user:, role: :reader) } }

    it "lets a reader view the wire through the API" do
      expect(described_class.new(reader, wire).show_in_v4?).to eq(true)
    end

    it "does not let a user outside the organization view the wire through the API" do
      expect(described_class.new(non_admin, wire).show_in_v4?).to eq(false)
    end

    it "keeps the web wire page limited to auditors" do
      expect(described_class.new(reader, wire).show?).to eq(false)
      expect(described_class.new(create(:user, access_level: :auditor), wire).show?).to eq(true)
    end
  end

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
