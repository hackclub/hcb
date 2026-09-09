# frozen_string_literal: true

require "rails_helper"

RSpec.describe AchTransferPolicy, type: :policy do
  describe "#visible_attributes" do
    let(:event) { create(:event, is_public: transparent) }
    let(:ach_transfer) { create(:ach_transfer, event:) }
    let(:transparent) { false }

    subject { described_class.new(user, ach_transfer).visible_attributes }

    # What a transparent organization shows to anyone. Mirrors what
    # Api::Entities::AchTransfer exposes in v3.
    base = %i[amount_cents date status recipient_name payment_for sender]
    reader_only = %i[recipient_email bank_name]
    manager_only = %i[account_number account_number_last4 routing_number]

    def organizer(event, role)
      create(:user).tap { |u| create(:organizer_position, user: u, event:, role:) }
    end

    context "when signed out" do
      let(:user) { nil }

      context "and the organization is private" do
        it { is_expected.to be_empty }
      end

      context "and the organization is transparent" do
        let(:transparent) { true }

        it { is_expected.to match_array(base) }

        it "does not expose counterparty or bank details" do
          expect(subject).not_to include(*reader_only, *manager_only)
        end
      end
    end

    context "as a user with no relationship to the organization" do
      let(:user) { create(:user) }

      it { is_expected.to be_empty }

      context "when the organization is transparent" do
        let(:transparent) { true }

        it { is_expected.to match_array(base) }
      end
    end

    context "as a reader" do
      let(:user) { organizer(event, :reader) }

      it { is_expected.to match_array(base + reader_only) }

      it "does not expose account or routing numbers" do
        expect(subject).not_to include(*manager_only)
      end
    end

    context "as a member" do
      let(:user) { organizer(event, :member) }

      it { is_expected.to match_array(base + reader_only) }
    end

    context "as a manager" do
      let(:user) { organizer(event, :manager) }

      it { is_expected.to match_array(base + reader_only + manager_only) }
    end

    context "as an auditor" do
      let(:user) { create(:user, :make_auditor) }

      it { is_expected.to match_array(base + reader_only) }
    end

    context "as an admin" do
      let(:user) { create(:user, :make_admin) }

      it { is_expected.to match_array(base + reader_only + manager_only) }
    end
  end

  # The read gate is derived from the field lattice rather than restated beside
  # it, which is what removes the need for a `show_in_v5?` fork.
  describe "#show_any_attribute?" do
    subject { described_class.new(user, ach_transfer).show_any_attribute? }

    let(:ach_transfer) { create(:ach_transfer, event:) }
    let(:user) { nil }

    context "on a transparent organization" do
      let(:event) { create(:event, is_public: true) }

      it { is_expected.to eq(true) }
    end

    context "on a private organization" do
      let(:event) { create(:event, is_public: false) }

      it { is_expected.to eq(false) }
    end
  end

end
