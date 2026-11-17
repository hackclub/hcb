# frozen_string_literal: true

require "rails_helper"

RSpec.describe SponsorPolicy, type: :policy do
  describe "#index?" do
    subject { described_class.new(user, Sponsor).index? }

    context "as an auditor" do
      let(:user) { create(:user, :make_auditor) }

      it { is_expected.to eq(true) }
    end

    context "as an organization manager" do
      let(:user) { create(:user) }

      before { create(:organizer_position, user:, role: :manager) }

      it { is_expected.to be_falsey }
    end

    context "when signed out" do
      let(:user) { nil }

      it { is_expected.to be_falsey }
    end
  end
end
