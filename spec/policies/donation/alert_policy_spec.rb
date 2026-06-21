# frozen_string_literal: true

require "rails_helper"

RSpec.describe Donation::AlertPolicy, type: :policy do
  let(:event) { create(:event) }
  let(:alert) { create(:donation_alert, event: event) }

  describe "#create?" do
    subject { described_class.new(user, alert).create? }

    context "as a manager" do
      let(:user) { create(:user) }

      before { create(:organizer_position, user: user, event: event, role: :manager) }

      it { is_expected.to be true }
    end

    context "as a member" do
      let(:user) { create(:user) }

      before { create(:organizer_position, user: user, event: event, role: :member) }

      it { is_expected.to be false }
    end

    context "as an admin" do
      let(:user) { create(:user, :make_admin) }

      it { is_expected.to be true }
    end

    context "as an auditor" do
      let(:user) { create(:user, access_level: "auditor") }

      it { is_expected.to be false }
    end

    context "as a non-member" do
      let(:user) { create(:user) }

      it { is_expected.to be false }
    end
  end

  describe "#update?" do
    subject { described_class.new(user, alert).update? }

    context "as a manager" do
      let(:user) { create(:user) }

      before { create(:organizer_position, user: user, event: event, role: :manager) }

      it { is_expected.to be true }
    end

    context "as a member" do
      let(:user) { create(:user) }

      before { create(:organizer_position, user: user, event: event, role: :member) }

      it { is_expected.to be false }
    end
  end

  describe "#destroy?" do
    subject { described_class.new(user, alert).destroy? }

    context "as a manager" do
      let(:user) { create(:user) }

      before { create(:organizer_position, user: user, event: event, role: :manager) }

      it { is_expected.to be true }
    end

    context "as a member" do
      let(:user) { create(:user) }

      before { create(:organizer_position, user: user, event: event, role: :member) }

      it { is_expected.to be false }
    end
  end

  describe "#show?" do
    subject { described_class.new(user, alert).show? }

    context "as a manager" do
      let(:user) { create(:user) }

      before { create(:organizer_position, user: user, event: event, role: :manager) }

      it { is_expected.to be true }
    end

    context "as a member" do
      let(:user) { create(:user) }

      before { create(:organizer_position, user: user, event: event, role: :member) }

      it { is_expected.to be false }
    end
  end
end
