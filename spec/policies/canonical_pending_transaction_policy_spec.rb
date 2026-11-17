# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransactionPolicy, type: :policy do
  let(:parent_event) { create(:event) }
  let(:event) { create(:event, parent: parent_event) }
  let(:canonical_pending_transaction) { create(:canonical_pending_transaction, event:) }

  def user_with_role(role, on:)
    create(:user).tap { |user| create(:organizer_position, user:, event: on, role:) }
  end

  describe "#show?" do
    it "permits a reader of the transaction's organization" do
      expect(described_class.new(user_with_role(:reader, on: event), canonical_pending_transaction).show?).to be(true)
    end

    it "permits a manager of a parent organization" do
      expect(described_class.new(user_with_role(:manager, on: parent_event), canonical_pending_transaction).show?).to be(true)
    end

    it "permits an auditor" do
      expect(described_class.new(create(:user, access_level: :auditor), canonical_pending_transaction).show?).to be(true)
    end

    it "refuses a manager of a sub-organization" do
      sub_event = create(:event, parent: event)

      expect(described_class.new(user_with_role(:manager, on: sub_event), canonical_pending_transaction).show?).to be(false)
    end

    it "refuses an unrelated user" do
      expect(described_class.new(create(:user), canonical_pending_transaction).show?).to be(false)
    end

    it "refuses a signed-out visitor" do
      expect(described_class.new(nil, canonical_pending_transaction).show?).to be(false)
    end

    it "refuses a non-auditor when the transaction has no organization" do
      unmapped = create(:canonical_pending_transaction)

      expect(described_class.new(user_with_role(:manager, on: event), unmapped).show?).to be(false)
    end
  end
end
