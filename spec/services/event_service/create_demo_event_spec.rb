# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventService::CreateDemoEvent, type: :model do
  let!(:point_of_contact) { create(:user, :make_admin) }
  let(:name) { "Event X" }
  let(:country) { "US" }

  context "when user does not exist" do
    let(:user_email) { "user@example.com" }

    let(:service) do
      EventService::CreateDemoEvent.new(
        name:,
        point_of_contact_id: point_of_contact.id,
        email: user_email,
        country:
      )
    end

    it "creates an event and user" do
      expect do
        service.run
      end.to change(Event, :count).by(1).and change(User, :count).by(1)
    end
  end

  context "when user already exists" do
    let!(:user) { create(:user) }
    let(:service) do
      EventService::CreateDemoEvent.new(
        name:,
        point_of_contact_id: point_of_contact.id,
        email: user.email,
        country:
      )
    end

    it "creates and event and invites the users" do
      expect do
        service.run
      end.to change(Event, :count).by(1).and change(User, :count).by(0).and change(OrganizerPositionInvite, :count).by(1)
    end
  end

  context "when user is already in multiple demo accounts" do
    let(:current_user) { create :user }
    let(:events) { create_list :event, 11, :demo_mode }

    before do
      events.each do |event|
        create(:organizer_position, event:, user: current_user)
      end
    end

    let(:service) do
      EventService::CreateDemoEvent.new(
        name:,
        point_of_contact_id: point_of_contact.id,
        email: current_user.email,
        country:
      )
    end

    it "does not create an event" do
      expect do
        service.run
      end.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Demo mode limit reached for user")
    end
  end
end
