# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventPolicy, type: :policy do
  describe "#sub_organizations?" do
    let(:event) { create(:event, is_public: true) }

    subject { described_class.new(nil, event).sub_organizations? }

    context "when the only sub-organization is private" do
      before { create(:event, parent: event, is_public: false) }

      it { is_expected.to eq(false) }
    end

    context "when the only sub-organization is hidden" do
      before { create(:event, parent: event, is_public: true, hidden_at: Time.current) }

      it { is_expected.to eq(false) }
    end

    context "when a transparent sub-organization exists" do
      before { create(:event, parent: event, is_public: true) }

      it { is_expected.to eq(true) }
    end

    context "when the only sub-organization has been deleted" do
      before { create(:event, parent: event, is_public: true).destroy }

      it { is_expected.to eq(false) }
    end

    context "as an organizer of an organization whose roster is entirely private" do
      let(:organizer) { create(:user) }

      subject { described_class.new(organizer, event).sub_organizations? }

      before do
        create(:organizer_position, user: organizer, event:)
        create(:event, parent: event, is_public: false)
      end

      it { is_expected.to eq(true) }
    end
  end

  describe "#create_sub_organization?" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }

    subject { described_class.new(user, event).create_sub_organization? }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
    end

    context "when sub-organizations are not enabled on the event" do
      before { create(:organizer_position, user:, event:, role: :manager) }

      it { is_expected.to eq(false) }
    end

    context "when sub-organizations are enabled" do
      before { event.config.update!(subevent_plan: Event::Plan::Standard.name) }

      context "as a manager" do
        before { create(:organizer_position, user:, event:, role: :manager) }

        it { is_expected.to eq(true) }
      end

      context "as a member" do
        before { create(:organizer_position, user:, event:, role: :member) }

        it "is denied by default" do
          is_expected.to eq(false)
        end

        it "is allowed when the member_subevent_creation flag is enabled for the event" do
          Flipper.enable(:member_subevent_creation, event)

          is_expected.to eq(true)
        end
      end

      context "as a reader" do
        before do
          create(:organizer_position, user:, event:, role: :reader)
          Flipper.enable(:member_subevent_creation, event)
        end

        it "is denied even when the flag is enabled" do
          is_expected.to eq(false)
        end
      end

      context "as an admin without a position" do
        let(:user) { create(:user, :make_admin) }

        it { is_expected.to eq(true) }
      end

      context "as a manager of an ancestor org creating on a subevent" do
        let(:subevent) { create(:event, parent: event) }

        subject { described_class.new(user, subevent).create_sub_organization? }

        before do
          create(:organizer_position, user:, event:, role: :manager)
          subevent.config.update!(subevent_plan: Event::Plan::Standard.name)
        end

        it "is allowed without the flag" do
          is_expected.to eq(true)
        end
      end
    end
  end

  describe "#ledger?" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }

    subject { described_class.new(user, event).ledger? }

    context "as a reader" do
      before { create(:organizer_position, user:, event:, role: :reader) }

      it "is denied without either ledger flag" do
        is_expected.to eq(false)
      end

      it "is allowed when the event has new_ledger_2026_06_30 enabled" do
        Flipper.enable(:new_ledger_2026_06_30, event)

        is_expected.to eq(true)
      end

      it "is allowed when the user has opted into new_ledger_2026_07_17" do
        Flipper.enable_actor(:new_ledger_2026_07_17, user)

        is_expected.to eq(true)
      end
    end

    context "as a non-member with the opt-in flag enabled" do
      before { Flipper.enable_actor(:new_ledger_2026_07_17, user) }

      it "is denied" do
        is_expected.to eq(false)
      end
    end

    context "as an auditor" do
      let(:user) { create(:user, :make_auditor) }

      it "is allowed without either flag" do
        is_expected.to eq(true)
      end
    end
  end
end
