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
        authorize @event, :sub_organizations_in_v4?

        @events = @event.subevents.includes(:users).order("organizer_positions.created_at DESC")
      end

      require_oauth2_scope "organizations:read", :sub_organizations

      def create_sub_organization
        parent_event = Event.find_by_public_id(params[:id]) || Event.find_by!(slug: params[:id])
        authorize parent_event, :create_sub_organization?

        # Use the current user as POC if they're an admin, otherwise use the system user (bank@hackclub.com)
        poc_id = current_user.admin? ? current_user.id : User.system_user.id

        @event = ::EventService::Create.new(
          name: params[:name],
          emails: [params[:email]],
          cosigner_email: params[:cosigner_email],
          is_signee: true,
          country: params[:country],
          point_of_contact_id: poc_id,
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

      def balance_by_date
        authorize @event, :show_in_v4?

        balance_by_date = Rails.cache.fetch("balance_by_date_#{@event.id}", expires_in: 5.minutes) do
          ::TransactionGroupingEngine::Transaction::All.new(event_id: @event.id).running_balance_by_date
        end

        balance_by_date = balance_by_date.dup
        balance_by_date[Date.today] = @event.balance_v2_cents

        @balance_series = balance_by_date.sort.map { |date, amount| { date: date.to_s, amount: } }
      end

      require_oauth2_scope "organizations:read", :balance_by_date

      private

      def set_event
        @event = Event.find_by_public_id(params[:id]) || Event.find_by!(slug: params[:id]) # we don't use set_api_event here because it is passed as id in the url
      end

    end
  end
end
