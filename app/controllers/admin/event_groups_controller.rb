# frozen_string_literal: true

module Admin
  class EventGroupsController < Admin::BaseController
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

    def statement_of_activity
      @event_group = Event::Group.preload(:events).strict_loading.find(params[:id])

      @statement_of_activity = Event::StatementOfActivity.new(
        @event_group,
        start_date_param: params[:start],
        end_date_param: params[:end]
      )
    end

    def event
      @event = Event.strict_loading.friendly.find(params[:event_id])
      @event_groups =
        Event::Group
        .strict_loading
        .preload(:user, memberships: :event)
        .order(name: :asc)

      render(layout: !turbo_frame_request?)
    end

    def update_event
      @event = Event.strict_loading.friendly.find(params[:event_id])

      filtered_params =
        params
        .permit(event: [:new_event_group_name, { event_group_ids: [] }])
        .fetch(:event, {})

      event_group_ids = filtered_params.fetch(:event_group_ids, [])

      ActiveRecord::Base.transaction do
        # Start by removing all group memberships that aren't referenced
        Event::GroupMembership
          .where(event: @event)
          .where.not(event_group_id: event_group_ids)
          .destroy_all

        # Find or create the referenced ones
        event_group_ids.each do |event_group_id|
          group = Event::Group.find_by(id: event_group_id)
          next unless group

          Event::GroupMembership.find_or_create_by!(group:, event: @event)
        end

        # Create a new group if required
        if filtered_params[:new_event_group_name].present?
          group = Event::Group.find_or_create_by!(user: current_user, name: filtered_params[:new_event_group_name])
          group.memberships.find_or_create_by!(event: @event)
        end
      end

      redirect_to(event_admin_event_groups_path(@event))
    end

  end
end
