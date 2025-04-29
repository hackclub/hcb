# frozen_string_literal: true

module Api
  module V4
    class SponsorsController < ApplicationController
      def index
        authorize Sponsor
        @sponsors = Sponsor.all.includes(:organization_id).order(created_at: :desc)
      end
    
      def show
        authorize @sponsor
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