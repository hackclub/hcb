# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizerPositionDeletionRequestPolicy, type: :policy do
  describe "#create?" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let(:target_position) { create(:organizer_position, event:, role: :member) }
    let(:opdr) { OrganizerPositionDeletionRequest.new(organizer_position: target_position) }

    subject { described_class.new(user, opdr).create? }

    context "as a reader" do
      let!(:own_position) { create(:organizer_position, user:, event:, role: :reader) }

      it "is allowed for their own position" do
        opdr.organizer_position = own_position

        is_expected.to eq(true)
      end

      it "is not allowed for another user's position" do
        is_expected.to eq(false)
      end
    end

    context "as a member" do
      let!(:own_position) { create(:organizer_position, user:, event:, role: :member) }

      it "is allowed for their own position" do
        opdr.organizer_position = own_position

        is_expected.to eq(true)
      end

      it "is not allowed for another user's position" do
        is_expected.to eq(false)
      end
    end

    context "as a manager" do
      before { create(:organizer_position, user:, event:, role: :manager) }

      it "is allowed for another user's position" do
        is_expected.to eq(true)
      end
    end

    context "as a user outside the organization" do
      it "is not allowed" do
        is_expected.to eq(false)
      end
    end
  end
end
