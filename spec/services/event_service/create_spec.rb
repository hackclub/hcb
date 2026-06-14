# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventService::Create do
  describe "#run" do
    let(:parent_event) { create(:event) }
    let(:creator) { create(:user) }
    let!(:parent_manager) { create(:organizer_position, event: parent_event, role: :manager) }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))

      # Avoid hitting the contract/DocuSeal flow triggered by signee invites.
      invite_model = instance_double(OrganizerPositionInvite, send_contract: true)
      invite_service = instance_double(OrganizerPositionInviteService::Create, run!: true, model: invite_model)
      allow(OrganizerPositionInviteService::Create).to receive(:new).and_return(invite_service)
    end

    def build_service(invited_by:)
      described_class.new(
        name: "New Budget",
        emails: ["organizer@example.com"],
        point_of_contact_id: User.system_user.id,
        invited_by:,
        parent_event:,
        plan: Event::Plan::Standard
      )
    end

    context "when created by a member of the parent" do
      before { create(:organizer_position, user: creator, event: parent_event, role: :member) }

      it "notifies the parent's managers" do
        expect { build_service(invited_by: creator).run }
          .to have_enqueued_mail(EventMailer, :subevent_created).once
      end
    end

    context "when created by a manager of the parent" do
      before { create(:organizer_position, user: creator, event: parent_event, role: :manager) }

      it "does not notify the parent's managers" do
        expect { build_service(invited_by: creator).run }
          .not_to have_enqueued_mail(EventMailer, :subevent_created)
      end
    end

    context "when created by an admin without a position" do
      let(:creator) { create(:user, :make_admin) }

      it "does not notify the parent's managers" do
        expect { build_service(invited_by: creator).run }
          .not_to have_enqueued_mail(EventMailer, :subevent_created)
      end
    end
  end
end
