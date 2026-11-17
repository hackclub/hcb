# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentPolicy, type: :policy do
  let(:parent_event) { create(:event) }
  let(:event) { create(:event, parent: parent_event) }
  let(:payment) { create(:payment, payee: create(:payee, event:)) }

  def user_with_role(role, on:)
    create(:user).tap { |user| create(:organizer_position, user:, event: on, role:) }
  end

  describe "#show?" do
    it "permits a reader of the payment's organization" do
      expect(described_class.new(user_with_role(:reader, on: event), payment).show?).to be(true)
    end

    it "permits a manager of a parent organization" do
      expect(described_class.new(user_with_role(:manager, on: parent_event), payment).show?).to be(true)
    end

    it "permits a reader of a parent organization" do
      expect(described_class.new(user_with_role(:reader, on: parent_event), payment).show?).to be(true)
    end

    it "permits a user of the payee's legal entity" do
      owner = create(:user).tap { |user| payment.legal_entity.users << user }

      expect(described_class.new(owner, payment).show?).to be(true)
    end

    it "permits an auditor" do
      expect(described_class.new(create(:user, access_level: :auditor), payment).show?).to be(true)
    end

    it "refuses a manager of a sub-organization" do
      sub_event = create(:event, parent: event)

      expect(described_class.new(user_with_role(:manager, on: sub_event), payment).show?).to be(false)
    end

    it "refuses an unrelated user" do
      expect(described_class.new(create(:user), payment).show?).to be(false)
    end

    it "refuses a signed-out visitor" do
      expect(described_class.new(nil, payment).show?).to be(false)
    end
  end
end
