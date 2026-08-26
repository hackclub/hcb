# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event, type: :model do
  let(:event) { create(:event) }

  it "is valid" do
    expect(event).to be_valid
  end

  it "defaults to approved" do
    expect(event).to be_approved
  end

  describe "#balance_v2_cents" do
    before do
      tx1 = create(:canonical_transaction, amount_cents: 100)
      tx2 = create(:canonical_transaction, amount_cents: 300)
      create(:canonical_event_mapping, canonical_transaction: tx1, event:)
      create(:canonical_event_mapping, canonical_transaction: tx2, event:)
    end

    it "calculates a value from canonical transactions" do
      result = event.balance_v2_cents

      expect(result).to eql(400).and eql(event.balance)
    end
  end

  describe "private" do
    before do
      create(:fee_relationship, fee_applies: true, event:, fee_amount: 10010)
      fee_payment = create(:transaction, amount: -10)
      create(:fee_relationship, is_fee_payment: true, event:, t_transaction: fee_payment)
    end
  end

  describe "#search_name" do
    context "when the search is a partial match" do
      it "returns the event" do
        event = create(:event, name: "Now in Ukraine")

        expect(Event.search_name("now in ukraine")).to contain_exactly(event)
        expect(Event.search_name("now in")).to contain_exactly(event)
        expect(Event.search_name("now")).to contain_exactly(event)
      end
    end
  end

  describe "total_fee_payments_v2_cents" do
    it "handles fee payments with an unknown hcb code" do
      # There are a few fee payments in prod that DON'T have an HCB-700 code.

      event = create(:event)

      expect {
        cem = create(
          :canonical_event_mapping,
          canonical_transaction: create(:canonical_transaction, amount_cents: -1000, hcb_code: "HCB-000-1"),
          event:,
          fee: create(:fee, reason: :hack_club_fee),
        )
      }.to change { event.reload.total_fee_payments_v2_cents }.from(0).to(1000)
    end
  end

  describe "#parent_id" do
    it "cannot be cyclical" do
      event1, event2, event3 = create_list(:event, 3)

      # Set up 1 -> 2 -> 3
      event2.update!(parent_id: event1.id)
      event3.update!(parent_id: event2.id)

      event1.parent_id = event3.id
      expect(event1.valid?).to eq(false)
      expect(event1.errors[:parent]).to eq(["is cyclical"])
    end

    it "cannot exceed the maximum depth" do
      stub_const("Event::MAX_PARENT_DEPTH", 3)

      event1, event2, event3, event4 = create_list(:event, 4)

      # Set up 1 -> 2 -> 3
      event2.update!(parent_id: event1.id)
      event3.update!(parent_id: event2.id)

      event4.parent_id = event3.id
      expect(event4.valid?).to eq(false)
      expect(event4.errors[:parent]).to eq(["max depth exceeded"])
    end
  end

  describe "#forced_transparency?" do
    let(:public_parent) { create(:event, is_public: true) }
    let(:private_parent) { create(:event, is_public: false) }

    it "is true for an Argosy event under a transparent parent" do
      event = create(:event, parent: public_parent, plan_type: Event::Plan::Argosy2025)

      expect(event.forced_transparency?).to eq(true)
    end

    it "is false for an Argosy event under a non-transparent parent" do
      event = create(:event, parent: private_parent, plan_type: Event::Plan::Argosy2026)

      expect(event.forced_transparency?).to eq(false)
    end

    it "is false for an Argosy event with no parent" do
      event = create(:event, plan_type: Event::Plan::Argosy2026)

      expect(event.forced_transparency?).to eq(false)
    end

    it "is false for a non-Argosy event under a transparent parent" do
      event = create(:event, parent: public_parent, plan_type: Event::Plan::FeeWaived)

      expect(event.forced_transparency?).to eq(false)
    end
  end

  describe "transparency enforcement" do
    it "forces transparency on an Argosy event under a transparent parent" do
      parent = create(:event, is_public: true)
      event = create(:event, parent:, is_public: false, plan_type: Event::Plan::Argosy2025)

      expect(event.is_public).to eq(true)
    end

    it "leaves a non-Argosy event under a transparent parent alone" do
      parent = create(:event, is_public: true)
      event = create(:event, parent:, is_public: false)

      expect(event.is_public).to eq(false)
    end

    it "removes transparency from an event that is ineligible for it" do
      event = create(:event, is_public: true, plan_type: Event::Plan::SalaryAccount)

      expect(event.is_public).to eq(false)
      expect(event.is_indexable).to eq(false)
    end
  end

  describe "#ancestor_ids" do
    it "returns ids ordered from self to root" do
      root = create(:event)
      child = create(:event, parent: root)
      grandchild = create(:event, parent: child)

      expect(grandchild.ancestor_ids).to eq([grandchild.id, child.id, root.id])
    end
  end

  describe "#ancestors" do
    it "returns events ordered from self to root" do
      root = create(:event)
      child = create(:event, parent: root)
      grandchild = create(:event, parent: child)

      expect(grandchild.ancestors.to_a).to eq([grandchild, child, root])
    end
  end

  describe "#ancestor_organizer_positions" do
    it "returns positions on self and all ancestors" do
      root = create(:event)
      child = create(:event, parent: root)
      grandchild = create(:event, parent: child)

      op_root = create(:organizer_position, event: root)
      op_child = create(:organizer_position, event: child)
      op_grandchild = create(:organizer_position, event: grandchild)

      expect(grandchild.ancestor_organizer_positions).to match_array([op_grandchild, op_child, op_root])
    end
  end

  describe "#visible_descendant_ids" do
    let(:root) { create(:event, is_public: true) }
    let!(:transparent_child) { create(:event, parent: root, is_public: true) }
    let!(:private_child) { create(:event, parent: root, is_public: false) }

    it "omits private descendants, and their subtrees, from a signed out visitor" do
      create(:event, parent: private_child, is_public: true)

      expect(root.visible_descendant_ids(nil)).to eq([transparent_child.id])
    end

    it "omits hidden descendants, and their subtrees, from a signed out visitor" do
      hidden_child = create(:event, parent: root, is_public: true, hidden_at: Time.current)
      create(:event, parent: hidden_child, is_public: true)

      expect(root.visible_descendant_ids(nil)).to eq([transparent_child.id])
    end

    it "omits private descendants from a user with no organizer positions" do
      expect(root.visible_descendant_ids(create(:user))).to eq([transparent_child.id])
    end

    it "includes transparent events nested under transparent events" do
      grandchild = create(:event, parent: transparent_child, is_public: true)

      expect(root.visible_descendant_ids(nil)).to match_array([transparent_child.id, grandchild.id])
    end

    it "includes private descendants for an admin" do
      admin = create(:user, :make_admin)

      expect(root.visible_descendant_ids(admin)).to match_array([transparent_child.id, private_child.id])
    end

    it "includes private and hidden descendants for a reader on the root" do
      user = create(:user)
      create(:organizer_position, event: root, user:, role: :reader)
      hidden_child = create(:event, parent: root, is_public: true, hidden_at: Time.current)

      expect(root.visible_descendant_ids(user)).to match_array(
        [transparent_child.id, private_child.id, hidden_child.id]
      )
    end

    it "includes a private descendant, and its subtree, for a user who organizes only it" do
      user = create(:user)
      create(:organizer_position, event: private_child, user:, role: :reader)
      grandchild = create(:event, parent: private_child, is_public: false)

      expect(root.visible_descendant_ids(user)).to match_array(
        [transparent_child.id, private_child.id, grandchild.id]
      )
    end
  end

  # EventPolicy#sub_organizations? asks this whether the page has anything on
  # it, so it has to agree with #visible_descendant_ids about who sees what.
  # Each example below asserts both, so a rule that drifts apart in one of them
  # fails here.
  describe "#visible_subevents" do
    let(:root) { create(:event, is_public: true) }

    it "is empty for a signed out visitor when only a private subtree exists", :aggregate_failures do
      private_child = create(:event, parent: root, is_public: false)
      create(:event, parent: private_child, is_public: true)

      expect(root.visible_subevents(nil)).to be_empty
      expect(root.visible_descendant_ids(nil)).to be_empty
    end

    it "is empty for a signed out visitor when only a hidden subtree exists", :aggregate_failures do
      hidden_child = create(:event, parent: root, is_public: true, hidden_at: Time.current)
      create(:event, parent: hidden_child, is_public: true)

      expect(root.visible_subevents(nil)).to be_empty
      expect(root.visible_descendant_ids(nil)).to be_empty
    end

    it "is empty when the only sub-organization has been deleted", :aggregate_failures do
      create(:event, parent: root, is_public: true).destroy

      expect(root.visible_subevents(nil)).to be_empty
      expect(Event.where(id: root.visible_descendant_ids(nil))).to be_empty
    end

    it "is empty for a user with no organizer positions on a private roster" do
      create(:event, parent: root, is_public: false)

      expect(root.visible_subevents(create(:user))).to be_empty
    end

    it "returns the transparent sub-organizations" do
      transparent_child = create(:event, parent: root, is_public: true)
      create(:event, parent: root, is_public: false)

      expect(root.visible_subevents(nil)).to eq([transparent_child])
    end
  end

  # A row that opens must be one #visible_subevents would fill.
  describe "#expandable_subevent_ids" do
    let(:root) { create(:event, is_public: true) }
    let!(:child) { create(:event, parent: root, is_public: true) }

    it "is empty when no sub-organization has sub-organizations of its own" do
      expect(root.expandable_subevent_ids(nil)).to be_empty
    end

    it "includes a sub-organization with a transparent sub-organization" do
      create(:event, parent: child, is_public: true)

      expect(root.expandable_subevent_ids(nil)).to eq(Set[child.id])
    end

    it "omits a sub-organization whose sub-organizations are all private" do
      create(:event, parent: child, is_public: false)

      expect(root.expandable_subevent_ids(nil)).to be_empty
    end

    it "omits a sub-organization whose sub-organizations are all hidden" do
      create(:event, parent: child, is_public: true, hidden_at: Time.current)

      expect(root.expandable_subevent_ids(nil)).to be_empty
    end

    it "includes private sub-organizations for an admin" do
      create(:event, parent: child, is_public: false)

      expect(root.expandable_subevent_ids(create(:user, :make_admin))).to eq(Set[child.id])
    end

    it "includes private sub-organizations for a reader on the root" do
      user = create(:user)
      create(:organizer_position, event: root, user:, role: :reader)
      create(:event, parent: child, is_public: false)

      expect(root.expandable_subevent_ids(user)).to eq(Set[child.id])
    end

    it "includes a private sub-organization the viewer organizes, along with its subtree" do
      user = create(:user)
      private_child = create(:event, parent: root, is_public: false)
      create(:organizer_position, event: private_child, user:, role: :reader)
      create(:event, parent: private_child, is_public: false)

      expect(root.expandable_subevent_ids(user)).to eq(Set[private_child.id])
    end

    it "ignores sub-organizations the viewer cannot see at all" do
      private_child = create(:event, parent: root, is_public: false)
      create(:event, parent: private_child, is_public: true)

      expect(root.expandable_subevent_ids(nil)).to be_empty
    end
  end

  describe "#plan" do
    it "uses the parent event's subevent plan by default" do
      parent = create(:event)
      parent.config.update!(subevent_plan: Event::Plan::HackClubAffiliate.name)
      child = create(:event, plan_type: nil, parent:)
      expect(child.plan).to be_instance_of(Event::Plan::HackClubAffiliate)
    end

    it "uses the parent's plan if a subevent plan isn't set" do
      parent = create(:event, plan_type: Event::Plan::HackClubAffiliate)
      child = create(:event, plan_type: nil, parent:)

      expect(child.plan).to be_instance_of(Event::Plan::HackClubAffiliate)
    end

    it "uses the standard plan as a fallback" do
      parent = create(:event)
      parent.plans.destroy_all
      child = create(:event, plan_type: nil, parent:)

      expect(child.plan).to be_instance_of(Event::Plan::Standard)
    end
  end

  describe "ledger association" do
    it "automatically creates a primary ledger after creation" do
      event = create(:event)

      expect(event.ledger).to be_present
      expect(event.ledger.primary?).to be true
      expect(event.ledger.event).to eq(event)
    end

    it "has a primary ledger association" do
      event = create(:event)

      expect(event).to respond_to(:ledger)
      expect(event.ledger).to be_a(Ledger)
    end
  end

  describe "#contract_pending_signature" do
    let(:event) { create(:event) }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
    end

    def build_contract
      invite = create(:organizer_position_invite, event:, user: create(:user))

      Contract::FiscalSponsorship.create!(contractable: invite, include_videos: false)
    end

    it "returns a contract that still needs signing" do
      contract = build_contract

      expect(event.contract_pending_signature).to eq contract
    end

    it "returns nothing once the contract is signed" do
      build_contract.update_column(:aasm_state, "signed")

      expect(event.contract_pending_signature).to be_nil
    end

    # The inactive organization banner keys off this, so a voided contract must
    # not leave an organization being told to sign something that no longer exists.
    it "returns nothing once the contract is voided" do
      build_contract.update_column(:aasm_state, "voided")

      expect(event.contract_pending_signature).to be_nil
    end

    it "returns the oldest of several open contracts" do
      first = build_contract
      build_contract

      expect(event.contract_pending_signature).to eq first
    end
  end

  describe "#can_front_balance" do
    it "enqueues a job to refresh the event's ledgers when changed" do
      expect { event.update!(can_front_balance: !event.can_front_balance) }
        .to have_enqueued_job(Event::RefreshLedgersJob).with(event_id: event.id)
    end

    it "does not enqueue a job when unchanged" do
      expect { event.update!(name: "Renamed") }
        .not_to have_enqueued_job(Event::RefreshLedgersJob)
    end
  end
end
