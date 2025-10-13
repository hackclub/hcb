# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::EventGroupMembershipsController do
  include SessionSupport
  render_views

  describe "#destroy" do
    it "removes the event from the given group" do
      user = create(:user, :make_admin)
      sign_in(user)

      event = create(:event)
      group = create(:event_group, user:)
      membership = Event::GroupMembership.create!(group:, event:)

      delete(:destroy, params: { event_group_id: group.id, id: membership.id })

      expect(response).to redirect_to(admin_event_groups_path)
      expect(flash[:success]).to eq("Event removed from group")

      expect(group.reload.events).not_to include(event)
    end
  end

end
