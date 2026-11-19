# frozen_string_literal: true

require "rails_helper"

RSpec.describe Announcement::BlockPolicy, type: :policy do
  let(:event) { create(:event) }
  let(:author) { create(:user) }
  let(:announcement) { Announcement.create!(event:, author:, title: "Update", content: {}) }
  let(:block) { Announcement::Block::TopUsers.create!(announcement:, parameters: {}) }

  before { create(:organizer_position, user: author, event:, role: :manager) }

  [:edit?, :update?].each do |action|
    describe "##{action}" do
      subject { described_class.new(user, block).public_send(action) }

      context "as the manager who wrote the announcement" do
        let(:user) { author }

        it { is_expected.to be(true) }
      end

      context "as a manager who did not write the announcement" do
        let(:user) { create(:user) }

        before { create(:organizer_position, user:, event:, role: :manager) }

        it { is_expected.to be(true) }
      end

      context "as a manager of the parent organization" do
        let(:parent) { create(:event) }
        let(:event) { create(:event, parent:) }
        let(:user) { create(:user) }

        before { create(:organizer_position, user:, event: parent, role: :manager) }

        it { is_expected.to be(true) }
      end

      context "as a member" do
        let(:user) { create(:user) }

        before { create(:organizer_position, user:, event:, role: :member) }

        it { is_expected.to be(false) }
      end

      context "as a reader" do
        let(:user) { create(:user) }

        before { create(:organizer_position, user:, event:, role: :reader) }

        it { is_expected.to be(false) }
      end

      context "as an admin" do
        let(:user) { create(:user, :make_admin) }

        it { is_expected.to be(true) }
      end

      context "as a user with no organizer position" do
        let(:user) { create(:user) }

        it { is_expected.to be(false) }
      end

      context "when signed out" do
        let(:user) { nil }

        it { is_expected.to be(false) }
      end
    end
  end
end
