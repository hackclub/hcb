# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizerPositionInviteService::Create do
  def create_event
    Event.create!({
                    name: "test-event",
                  })
  end

  context "associated user" do
    context "when it does not exist" do
      it "creates the user before creating the invite" do
        event = create_event
        sender = User.create!(email: "sender@example.com")

        invitee_email = "invitee@example.com"
        expect(User.find_by(email: invitee_email)).to be_nil

        expect do
          OrganizerPositionInviteService::Create.new(event:,
                                                     sender:,
                                                     user_email: invitee_email).run!
        end.to change{ OrganizerPositionInvite.count }.by(1)

        invite = OrganizerPositionInvite.last
        invited_user = User.find_by(email: invitee_email)
        expect(invited_user).to be_present
        expect(invite.user).to eq(invited_user)
        expect(invite.sender).to eq(sender)
        expect(invite.event).to eq(event)
      end
    end

    context "when it does exist" do
      it "associates the existing user to the newly created invite" do
        event = create_event
        sender = User.create!(email: "sender@example.com")
        invited_user = User.create!(email: "invitee@example.com")

        expect do
          OrganizerPositionInviteService::Create.new(event:,
                                                     sender:,
                                                     user_email: invited_user.email).run!
        end.to change{ OrganizerPositionInvite.count }.by(1)

        invite = OrganizerPositionInvite.last
        expect(invite.user).to eq(invited_user)
        expect(invite.sender).to eq(sender)
        expect(invite.event).to eq(event)
      end
    end
  end

  context "persist fails" do
    context "when calling run" do
      it "returns false without exception" do
        invite_count_before = OrganizerPositionInvite.count

        service = OrganizerPositionInviteService::Create.new(event: nil,
                                                             sender: nil,
                                                             user_email: "invitee@example.com")
        expect(service.run).to be_falsy
        expect(OrganizerPositionInvite.count).to eq(invite_count_before)
      end
    end

    context "when calling run!" do
      it "throws an exception" do
        invite_count_before = OrganizerPositionInvite.count

        service = OrganizerPositionInviteService::Create.new(event: nil,
                                                             sender: nil,
                                                             user_email: "invitee@example.com")
        expect do
          service.run!
        end.to raise_error(ActiveRecord::RecordInvalid)
        expect(OrganizerPositionInvite.count).to eq(invite_count_before)
      end
    end
  end
end
