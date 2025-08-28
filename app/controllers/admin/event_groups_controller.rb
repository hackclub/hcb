# frozen_string_literal: true

module Admin
  class EventGroupsController < AdminController
    def index
      @event_groups =
        Event::Group
        .preload(:user, memberships: :event)
        .order(name: :asc)
        .strict_loading

      @event_group = Event::Group.new
    end

    def create
      @event_group = current_user.event_groups.new(params.require(:event_group).permit(:name))

      if @event_group.save
        flash[:success] = "Group created"
      else
        flash[:error] = @event_group.errors.full_messages.to_sentence
      end

      redirect_to(admin_event_groups_path)
    end

    def destroy
      @event_group = Event::Group.find(params[:id])
      @event_group.destroy!

      flash[:success] = "Group successfully deleted"
      redirect_to(admin_event_groups_path)
    end

  end
end
