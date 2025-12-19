# frozen_string_literal: true

module Api
  module V4
    class EventsController < ApplicationController
      before_action :set_event, except: [:index, :create_sub_organization]
      skip_after_action :verify_authorized, only: [:index]

      def index
        @events = current_user.events.not_hidden.includes(:users).order("organizer_positions.created_at DESC")
      end

      def sub_organizations
        authorize @event, :sub_organizations?

        @events = @event.subevents.includes(:users).order("organizer_positions.created_at DESC")
      end

      require_oauth2_scope "organizations:read", :sub_organizations

      def create_sub_organization
        parent_event = Event.find_by_public_id(params[:id]) || Event.find_by!(slug: params[:id])
        authorize parent_event, :create_sub_organization?

        if params[:email].blank? || params[:name].blank?
          messages = []
          messages << "Organizer email is required" if params[:email].blank?
          messages << "Organization name is required" if params[:name].blank?
          render json: { error: "invalid_operation", messages: }, status: :bad_request and return
        end

        @event = ::EventService::Create.new(
          name: params[:name],
          emails: [params[:email]],
          cosigner_email: params[:cosigner_email],
          is_signee: true,
          country: params[:country],
          point_of_contact_id: parent_event.point_of_contact_id,
          invited_by: current_user,
          is_public: parent_event.is_public,
          plan: parent_event.config.subevent_plan.presence,
          risk_level: parent_event.risk_level,
          parent_event: parent_event,
          scoped_tags: params[:scoped_tags]
        ).run

        render :show, status: :created, location: api_v4_event_path(@event)
      end

      def show
        authorize @event, :show_in_v4?
      end

      require_oauth2_scope "organizations:read", :show

      def followers
        authorize @event, :show_in_v4?
        @followers = @event.followers
      end

      require_oauth2_scope "event_followers", :followers

      private

      def set_event
        @event = Event.find_by_public_id(params[:id]) || Event.find_by!(slug: params[:id]) # we don't use set_api_event here because it is passed as id in the url
      end

    end
  end
end
