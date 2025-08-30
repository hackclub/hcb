# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::GroupMembership do
  it "cannot contain duplicate entries" do
    event = create(:event)
    user = create(:user)
    group = Event::Group.create!(user:, name: "Scrapyard")

    _existing = described_class.create!(group:, event:)

    expect do
      described_class.insert!({ event_group_id: group.id, event_id: event.id })
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
