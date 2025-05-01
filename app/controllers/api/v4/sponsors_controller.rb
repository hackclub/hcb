# frozen_string_literal: true

module Api
  module V4
    class SponsorsController < ApplicationController
      def index
        @event = authorize(Event.find_by_public_id(params[:organization_id]) || Event.friendly.find(params[:organization_id]), :index?)
        @sponsors = @event.sponsors.includes(:user, :event).order(created_at: :desc)
      end
    
      def show
        @sponsor = authorize Sponsor.friendly.find(params[:id])
      end
    
      def create
        @sponsor = Sponsor.new(params[:sponsor])
        @sponsor.event_id = params[:sponsor][:organization_id]
        authorize @sponsor
      
        if @sponsor.save
          render :show
        else
          return render json: { error: e.message }, status: :internal_server_error
        end
      end
    end
  end
end