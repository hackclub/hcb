# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentPolicy, type: :policy do
  def create_hcb_code_for_event(event)
    disbursement = create(:disbursement, source_event: event)
    disbursement.outgoing_disbursement.local_hcb_code
  end

  describe "#users" do
    context "when commentable responds to :events (HcbCode)" do
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

        expect(policy.send(:users)).to include(direct_user, ancestor_user)
      end
    end

    context "when commentable is a Reimbursement::Report" do
      it "includes the report user and event organizers" do
        event = create(:event)
        organizer = create(:user)
        create(:organizer_position, event: event, user: organizer)
        report_user = create(:user)
        report = create(:reimbursement_report, user: report_user, event: event)

        comment = create(:comment, commentable: report)
        policy = described_class.new(report_user, comment)

        expect(policy.send(:users)).to include(report_user, organizer)
      end
    end

    context "when commentable is a Disbursement" do
      it "includes users from both source and destination events, plus their ancestors" do
        source_parent = create(:event)
        source_ancestor_user = create(:user)
        create(:organizer_position, event: source_parent, user: source_ancestor_user)
        source_event = create(:event, parent: source_parent)
        source_user = create(:user)
        create(:organizer_position, event: source_event, user: source_user)

        destination_parent = create(:event)
        destination_ancestor_user = create(:user)
        create(:organizer_position, event: destination_parent, user: destination_ancestor_user)
        destination_event = create(:event, parent: destination_parent)
        destination_user = create(:user)
        create(:organizer_position, event: destination_event, user: destination_user)

        disbursement = create(:disbursement, source_event: source_event, event: destination_event)

        comment = create(:comment, commentable: disbursement)
        policy = described_class.new(source_user, comment)

        expect(policy.send(:users)).to include(source_user, destination_user, source_ancestor_user, destination_ancestor_user)
      end
    end

    context "when commentable is an Event" do
      it "returns no users" do
        event = create(:event)
        user = create(:user)
        create(:organizer_position, event: event, user: user)

        comment = create(:comment, commentable: event)
        policy = described_class.new(user, comment)

        expect(policy.send(:users)).to be_empty
      end
    end

    context "when commentable falls through to the default branch (AchTransfer)" do
      it "returns the event's users" do
        event = create(:event, :with_positive_balance)
        user = create(:user)
        create(:organizer_position, event: event, user: user)
        ach_transfer = create(:ach_transfer, event: event)

        comment = create(:comment, commentable: ach_transfer)
        policy = described_class.new(user, comment)

        expect(policy.send(:users)).to include(user)
      end
    end

    context "when commentable responds to :author" do
      it "includes the author" do
        author = create(:user)
        disbursement = create(:disbursement, requested_by: author)
        hcb_code = disbursement.outgoing_disbursement.local_hcb_code

        comment = create(:comment, commentable: hcb_code)
        policy = described_class.new(author, comment)

        expect(policy.send(:users)).to include(author)
      end
    end
  end

  describe "#show?" do
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

  describe "#create?" do
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
