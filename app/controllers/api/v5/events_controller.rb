# frozen_string_literal: true

module Api
  module V5
    class EventsController < ApplicationController
      # Unlike v4, which lists only `current_user.events`, the v5 index is a
      # policy scope: signed in it is your organizations plus every transparent
      # one, signed out it is the transparent ones. That is the v3 directory and
      # the v4 organization list served by a single route.
      def index
        @events = policy_scope(Event).includes(:plan).order(created_at: :desc)
        @events = paginate_cursor(@events.to_a, &:public_id)
      end

      require_oauth2_scope "organizations:read", :index

      def show
        @event = authorize find_event, :show_any_attribute?
      end

      require_oauth2_scope "organizations:read", :show

      def sub_organizations
        @event = authorize find_event, :sub_organizations?

        @events = @event.visible_subevents(current_user).includes(:plan).order(created_at: :desc)
        @events = paginate_cursor(@events.to_a, &:public_id)
      end

      require_oauth2_scope "organizations:read", :sub_organizations

      def followers
        @event = authorize find_event, :show_any_attribute?
        @followers = @event.followers
      end

      require_oauth2_scope "event_followers", :followers

      def balance_by_date
        @event = authorize find_event, :balance_by_date?

        balance_by_date = Rails.cache.fetch("balance_by_date_#{@event.id}", expires_in: 5.minutes) do
          ::TransactionGroupingEngine::Transaction::All.new(event_id: @event.id).running_balance_by_date
        end

        balance_by_date = balance_by_date.dup
        balance_by_date[Date.today] = @event.balance_v2_cents

        start_date = [@event.created_at.to_date, 1.year.ago.to_date].max
        @balance_series = balance_by_date.sort.filter_map { |date, amount| { date: date.to_s, amount: } if date >= start_date }
      end

      require_oauth2_scope "organizations:read", :balance_by_date

      private

      # Organizations are addressable by public id or slug, as in v4.
      def find_event
        id = params[:id] || params[:organization_id]

        Event.find_by_public_id(id) || Event.friendly.find(id)
      end

    end
  end
end
