# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentPolicy, type: :policy do
  def create_hcb_code_for_event(event)
    disbursement = create(:disbursement, source_event: event)
    disbursement.outgoing_disbursement.local_hcb_code
  end

  describe "#users" do
    context "when commentable responds to :events" do
      it "includes both direct users and ancestor users" do
        parent_event = create(:event)
        ancestor_user = create(:user)
        create(:organizer_position, event: parent_event, user: ancestor_user)

        child_event = create(:event, parent: parent_event)
        direct_user = create(:user)
        create(:organizer_position, event: child_event, user: direct_user)

        hcb_code = create_hcb_code_for_event(child_event)
        comment = create(:comment, commentable: hcb_code)
        policy = described_class.new(direct_user, comment)
        policy_users = policy.send(:users)

        expect(policy_users).to include(direct_user)
        expect(policy_users).to include(ancestor_user)
      end
    end
  end

  describe "#show?" do
    context "when commentable responds to :events" do
      it "allows organizers of the event to view comments" do
        event = create(:event)
        user = create(:user)
        create(:organizer_position, event: event, user: user)

        hcb_code = create_hcb_code_for_event(event)
        comment = create(:comment, commentable: hcb_code, admin_only: false)
        policy = described_class.new(user, comment)

        expect(policy.show?).to eq(true)
      end
    end
  end

  describe "#create?" do
    context "when commentable responds to :events" do
      it "allows organizers to create comments" do
        event = create(:event)
        user = create(:user)
        create(:organizer_position, event: event, user: user)

        hcb_code = create_hcb_code_for_event(event)
        comment = build(:comment, commentable: hcb_code, admin_only: false)
        policy = described_class.new(user, comment)

        expect(policy.create?).to eq(true)
      end
    end
  end
end
