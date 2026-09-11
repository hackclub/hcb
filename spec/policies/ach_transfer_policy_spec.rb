# frozen_string_literal: true

require "rails_helper"

RSpec.describe AchTransferPolicy, type: :policy do
  describe "#visible_attributes" do
    let(:event) { create(:event, :with_positive_balance, is_public: transparent) }
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
      let(:event) { create(:event, :with_positive_balance, is_public: true) }

      it { is_expected.to eq(true) }
    end

    context "on a private organization" do
      let(:event) { create(:event, :with_positive_balance, is_public: false) }

      it { is_expected.to eq(false) }
    end
  end


  describe "Scope" do
    def resolve(user)
      described_class::Scope.new(user, AchTransfer).resolve
    end

    def organizer(event, role)
      create(:user).tap { |u| create(:organizer_position, user: u, event:, role:) }
    end

    let!(:transparent_event) { create(:event, :with_positive_balance, is_public: true) }
    let!(:private_event)     { create(:event, :with_positive_balance, is_public: false) }
    let!(:transparent_ach)   { create(:ach_transfer, event: transparent_event) }
    let!(:private_ach)       { create(:ach_transfer, event: private_event) }

    it "returns only transparent organizations' transfers when signed out" do
      expect(resolve(nil)).to contain_exactly(transparent_ach)
    end

    it "returns only transparent organizations' transfers to an unrelated user" do
      expect(resolve(create(:user))).to contain_exactly(transparent_ach)
    end

    it "adds the reader's own organization" do
      reader = organizer(private_event, :reader)

      expect(resolve(reader)).to contain_exactly(transparent_ach, private_ach)
    end

    # The leak an index route has to rule out: another organization's reader
    # must not pick up this organization's rows.
    it "does not leak an unrelated private organization to a reader elsewhere" do
      other_event = create(:event, :with_positive_balance, is_public: false)
      create(:ach_transfer, event: other_event)
      reader = organizer(private_event, :reader)

      expect(resolve(reader)).not_to include(*other_event.ach_transfers)
    end

    it "returns everything to an auditor" do
      expect(resolve(create(:user, :make_auditor))).to include(transparent_ach, private_ach)
    end

    it "excludes hidden organizations even when they are public" do
      hidden = create(:event, :with_positive_balance, is_public: true, hidden_at: Time.current)
      hidden_ach = create(:ach_transfer, event: hidden)

      expect(resolve(nil)).not_to include(hidden_ach)
    end

    # The invariant that keeps the SQL scope and the Ruby policy from drifting.
    # Equality is too strong — the scope is deliberately narrower for hidden
    # public organizations (see Event.visible_to) — but it must never be
    # broader, or an index would surface a record #show would refuse.
    it "never returns a record the policy would refuse" do
      reader = organizer(private_event, :reader)
      create(:ach_transfer, event: create(:event, :with_positive_balance, is_public: false))
      create(:ach_transfer, event: create(:event, :with_positive_balance, is_public: true, hidden_at: Time.current))

      [nil, create(:user), reader, create(:user, :make_auditor)].each do |user|
        resolve(user).each do |ach_transfer|
          expect(described_class.new(user, ach_transfer).show_any_attribute?)
            .to eq(true), "scope returned #{ach_transfer.public_id} for #{user.inspect}, but the policy refuses it"
        end
      end
    end
  end


  # `#auditor_or_user?` swapped OrganizerPosition.role_at_least? for a memoized
  # id set to kill a per-row query. That is only safe while the two agree, so
  # assert it directly rather than by inspection.
  describe "role checks match OrganizerPosition.role_at_least?" do
    let(:grandparent) { create(:event, :with_positive_balance) }
    let(:parent)      { create(:event, :with_positive_balance).tap { |e| e.update!(parent: grandparent) } }
    let(:child)       { create(:event, :with_positive_balance).tap { |e| e.update!(parent:) } }
    let(:unrelated)   { create(:event, :with_positive_balance) }

    def reader_via_policy(user, event)
      described_class.new(user, create(:ach_transfer, event:)).send(:auditor_or_user?)
    end

    def reader_via_role_check(user, event)
      user&.auditor? || OrganizerPosition.role_at_least?(user, event, :reader)
    end

    def manager_via_policy(user, event)
      described_class.new(user, create(:ach_transfer, event:)).send(:admin_or_manager?)
    end

    def manager_via_role_check(user, event)
      user&.admin? || OrganizerPosition.role_at_least?(user, event, :manager)
    end

    [
      ["a direct reader",              :reader,  :child],
      ["a reader of the parent",       :reader,  :parent],
      ["a reader of the grandparent",  :reader,  :grandparent],
      ["a member",                     :member,  :child],
      ["a manager",                    :manager, :child],
      ["a manager of the grandparent", :manager, :grandparent],
    ].each do |label, role, position_on|
      it "agrees for #{label}" do
        user = create(:user)
        create(:organizer_position, user:, event: public_send(position_on), role:)

        [grandparent, parent, child, unrelated].each do |event|
          expect(reader_via_policy(user, event))
            .to eq(reader_via_role_check(user, event)),
                "reader check disagreed for #{label} looking at #{event.name}"
          expect(manager_via_policy(user, event))
            .to eq(manager_via_role_check(user, event)),
                "manager check disagreed for #{label} looking at #{event.name}"
        end
      end
    end

    it "agrees for an unrelated user, a signed-out visitor, an auditor and an admin" do
      [nil, create(:user), create(:user, :make_auditor), create(:user, :make_admin)].each do |user|
        [parent, child, unrelated].each do |event|
          expect(reader_via_policy(user, event))
            .to eq(reader_via_role_check(user, event)),
                "reader check disagreed for #{user.inspect} looking at #{event.name}"
          expect(manager_via_policy(user, event))
            .to eq(manager_via_role_check(user, event)),
                "manager check disagreed for #{user.inspect} looking at #{event.name}"
        end
      end
    end
  end

end
