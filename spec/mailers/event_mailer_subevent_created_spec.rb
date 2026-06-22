# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventMailer, type: :mailer do
  describe "#subevent_created" do
    let(:parent_event) { create(:event) }
    let(:subevent) { create(:event, parent: parent_event, name: "New Budget") }
    let(:creator) { create(:user, full_name: "Member McMemberface") }

    let(:manager) { create(:user) }
    let(:member) { create(:user) }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
      create(:organizer_position, user: manager, event: parent_event, role: :manager)
      create(:organizer_position, user: member, event: parent_event, role: :member)
    end

    let(:mailer) { EventMailer.with(event: parent_event, subevent:, creator:).subevent_created }

    it "is sent only to managers of the parent event" do
      expect(mailer.to).to include(manager.email)
      expect(mailer.to).not_to include(member.email)
    end

    it "renders a subject naming the parent, creator, and sub-organization" do
      expect(mailer.subject).to eq("[#{parent_event.name}] #{creator.name} created #{subevent.name}, a new sub-organization under #{parent_event.name}")
    end

    it "links to the new sub-organization in the body" do
      expect(mailer.body.encoded).to include(subevent.name)
      expect(mailer.body.encoded).to include(creator.name)
    end
  end
end
