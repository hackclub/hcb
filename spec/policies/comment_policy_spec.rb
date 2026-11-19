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

      it "includes users of parent organizations" do
        parent_event = create(:event)
        parent_user = create(:user)
        create(:organizer_position, event: parent_event, user: parent_user)
        event = create(:event, :with_positive_balance, parent: parent_event)
        ach_transfer = create(:ach_transfer, event:)

        comment = create(:comment, commentable: ach_transfer)
        policy = described_class.new(parent_user, comment)

        expect(policy.send(:users)).to include(parent_user)
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

  shared_examples "a thread open to the organization and its parents" do
    let(:parent_event) { create(:event) }
    let(:event) { create(:event, parent: parent_event) }

    def member_of(event, role)
      create(:user).tap { |user| create(:organizer_position, event:, user:, role:) }
    end

    def policy_for(user)
      described_class.new(user, build(:comment, commentable:))
    end

    it "lets the organization's members and parent organization members see and comment" do
      [member_of(event, :reader), member_of(parent_event, :manager), member_of(parent_event, :member), member_of(parent_event, :reader)].each do |user|
        policy = policy_for(user)

        expect(policy.new?).to eq(true)
        expect(policy.create?).to eq(true)
        expect(policy.show?).to eq(true)
      end
    end

    it "lets parent organization members edit and delete their own comments" do
      user = member_of(parent_event, :manager)
      policy = described_class.new(user, create(:comment, commentable:, user:))

      expect(policy.edit?).to eq(true)
      expect(policy.destroy?).to eq(true)
    end

    it "does not let other users see or comment" do
      [create(:user), member_of(create(:event), :manager)].each do |user|
        policy = policy_for(user)

        expect(policy.new?).to eq(false)
        expect(policy.create?).to eq(false)
        expect(policy.show?).to eq(false)
      end
    end
  end

  describe "comments on a payment" do
    before { allow(PaymentMailer).to receive(:with).and_return(double.as_null_object) }

    let(:commentable) { create(:payment, payee: create(:payee, event:)) }

    include_examples "a thread open to the organization and its parents"
  end

  describe "comments on a card grant" do
    before { allow_any_instance_of(CardGrant).to receive(:transfer_money) }

    let(:commentable) { create(:card_grant, event:) }

    include_examples "a thread open to the organization and its parents"
  end
end
