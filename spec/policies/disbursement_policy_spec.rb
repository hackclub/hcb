# frozen_string_literal: true

require "rails_helper"

RSpec.describe DisbursementPolicy, type: :policy do
  def user_with_role(role, on:)
    create(:user).tap { |user| create(:organizer_position, user:, event: on, role:) }
  end

  describe "#transfer_confirmation_letter?" do
    let(:source_parent) { create(:event) }
    let(:source_event) { create(:event, parent: source_parent) }
    let(:destination_parent) { create(:event) }
    let(:destination_event) { create(:event, parent: destination_parent) }
    let(:disbursement) { create(:disbursement, :deposited, source_event:, event: destination_event) }

    it "permits a reader of the sending organization" do
      expect(described_class.new(user_with_role(:reader, on: source_event), disbursement).transfer_confirmation_letter?).to be(true)
    end

    it "permits a manager of the sending organization" do
      expect(described_class.new(user_with_role(:manager, on: source_event), disbursement).transfer_confirmation_letter?).to be(true)
    end

    it "permits a reader of the receiving organization" do
      expect(described_class.new(user_with_role(:reader, on: destination_event), disbursement).transfer_confirmation_letter?).to be(true)
    end

    it "permits a manager of a parent of either organization" do
      expect(described_class.new(user_with_role(:manager, on: source_parent), disbursement).transfer_confirmation_letter?).to be(true)
      expect(described_class.new(user_with_role(:manager, on: destination_parent), disbursement).transfer_confirmation_letter?).to be(true)
    end

    it "permits an auditor" do
      expect(described_class.new(create(:user, :make_auditor), disbursement).transfer_confirmation_letter?).to be(true)
    end

    it "refuses a manager of an unrelated organization" do
      expect(described_class.new(user_with_role(:manager, on: create(:event)), disbursement).transfer_confirmation_letter?).to be(false)
    end

    it "refuses a manager of a sub-organization of either organization" do
      expect(described_class.new(user_with_role(:manager, on: create(:event, parent: source_event)), disbursement).transfer_confirmation_letter?).to be(false)
      expect(described_class.new(user_with_role(:manager, on: create(:event, parent: destination_event)), disbursement).transfer_confirmation_letter?).to be(false)
    end

    it "refuses a signed-out visitor" do
      expect(described_class.new(nil, disbursement).transfer_confirmation_letter?).to be(false)
    end
  end
end
