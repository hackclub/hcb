# frozen_string_literal: true

module Admin
  class EventGroupMembershipsController < Admin::BaseController
    def destroy
      @event_group = Event::Group.find(params[:event_group_id])
      @membership = @event_group.memberships.find(params[:id])
      @membership.destroy!

      flash[:success] = "Event removed from group"
      redirect_to(admin_event_groups_path)
    end

  end
end
