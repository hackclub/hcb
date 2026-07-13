# frozen_string_literal: true

require "rails_helper"

RSpec.describe FlipperGroups do
  describe ".hcb_team?" do
    it "is true for a user anywhere in the org tree" do
      melanie = create(:user, email: "melanie@hackclub.com")

      expect(described_class.hcb_team?(melanie)).to be(true)
    end

    it "is true for a member listed by usr_ public id rather than email" do
      member = create(:user, email: "someone-else@example.com")
      stub_const("HackClub::OrgChart::TREE", { melanie: [member.public_id] })

      expect(described_class.hcb_team?(member)).to be(true)
    end

    it "is false for a user not in the org tree" do
      outsider = create(:user, email: "outsider@example.com")

      expect(described_class.hcb_team?(outsider)).to be(false)
    end

    it "is false for a non-User actor" do
      expect(described_class.hcb_team?(create(:event))).to be(false)
    end

    it "does not match an Event whose id collides with a User id in the set" do
      event = create(:event)
      allow(described_class).to receive(:hcb_team_user_ids).and_return(Set[event.id])

      expect(described_class.hcb_team?(event)).to be(false)
    end
  end

  describe ".hcb_engineer?" do
    it "is true for a user in gary's subtree" do
      manu = create(:user, email: "manu@hackclub.com")

      expect(described_class.hcb_engineer?(manu)).to be(true)
    end

    it "is true for gary" do
      gary = create(:user, email: "gary@hackclub.com")

      expect(described_class.hcb_engineer?(gary)).to be(true)
    end

    it "is false for a team member outside gary's subtree" do
      sean = create(:user, email: "sean@hackclub.com") # reports to lucy, not gary

      expect(described_class.hcb_engineer?(sean)).to be(false)
    end
  end

  describe ".hq_descendant_user?" do
    let(:hq_root) { create(:event) }

    before { stub_const("#{described_class}::HQ_ROOT_EVENT_IDS", [hq_root.id]) }

    it "is true for an admin even when pretending not to be an admin" do
      admin = create(:user, :make_admin, pretend_is_not_admin: true)

      expect(described_class.hq_descendant_user?(admin)).to be(true)
    end

    it "is true for an auditor" do
      auditor = create(:user, access_level: :auditor)

      expect(described_class.hq_descendant_user?(auditor)).to be(true)
    end

    it "is true for a manager of an HQ root event" do
      user = create(:user)
      create(:organizer_position, event: hq_root, user:, role: :manager)

      expect(described_class.hq_descendant_user?(user)).to be(true)
    end

    it "is true for a manager of a descendant of an HQ root event" do
      child = create(:event, parent: hq_root)
      user = create(:user)
      create(:organizer_position, event: child, user:, role: :manager)

      expect(described_class.hq_descendant_user?(user)).to be(true)
    end

    it "is false for a manager of an ancestor of an HQ root event" do
      grandparent = create(:event)
      root = create(:event, parent: grandparent)
      stub_const("#{described_class}::HQ_ROOT_EVENT_IDS", [root.id])
      user = create(:user)
      create(:organizer_position, event: grandparent, user:, role: :manager)

      expect(described_class.hq_descendant_user?(user)).to be(false)
    end

    it "is false for a manager of an unrelated event" do
      user = create(:user)
      create(:organizer_position, event: create(:event), user:, role: :manager)

      expect(described_class.hq_descendant_user?(user)).to be(false)
    end

    it "is false for a non-manager member of an HQ event" do
      user = create(:user)
      create(:organizer_position, event: hq_root, user:, role: :member)

      expect(described_class.hq_descendant_user?(user)).to be(false)
    end

    it "is false for a non-User actor" do
      expect(described_class.hq_descendant_user?(hq_root)).to be(false)
    end
  end

  describe ".hq_descendant_organization?" do
    let(:hq_root) { create(:event) }

    before { stub_const("#{described_class}::HQ_ROOT_EVENT_IDS", [hq_root.id]) }

    it "is true for an HQ root organization" do
      expect(described_class.hq_descendant_organization?(hq_root)).to be(true)
    end

    it "is true for a descendant of an HQ root organization" do
      child = create(:event, parent: hq_root)

      expect(described_class.hq_descendant_organization?(child)).to be(true)
    end

    it "is false for an ancestor of an HQ root organization" do
      grandparent = create(:event)
      root = create(:event, parent: grandparent)
      stub_const("#{described_class}::HQ_ROOT_EVENT_IDS", [root.id])

      expect(described_class.hq_descendant_organization?(grandparent)).to be(false)
    end

    it "is false for an unrelated organization" do
      expect(described_class.hq_descendant_organization?(create(:event))).to be(false)
    end

    it "is false for a non-Event actor" do
      expect(described_class.hq_descendant_organization?(create(:user))).to be(false)
    end
  end

  describe "resilience of the cached id sets" do
    it "reports a missing HQ root event rather than silently dropping it" do
      present = create(:event)
      stub_const("#{described_class}::HQ_ROOT_EVENT_IDS", [present.id, 999_999])

      expect(Rails.error).to receive(:report).with(an_instance_of(StandardError))

      expect(described_class.hq_event_ids).to include(present.id)
    end

    it "reports and does not cache an unexpectedly-empty id set" do
      allow(HackClub::OrgChart).to receive(:user_ids).and_return([])

      expect(Rails.error).to receive(:report).with(an_instance_of(StandardError))

      expect(described_class.hcb_team_user_ids).to eq(Set.new)
    end
  end
end
