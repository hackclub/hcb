# frozen_string_literal: true

module Api
  module V4
    class SponsorsController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:index, :create]

      def index
        @sponsors = authorize(@event.sponsors.order(created_at: :desc))
      end

      def show
        @sponsor = Sponsor.find_by_public_id(params[:id])
        authorize @sponsor
      rescue => e
        return render json: { error: e.message }, status: :bad_request
      end

      def create
        authorize @event

        sponsor = params.require(:sponsor).permit(
          :address_city,
          :address_country,
          :address_line1,
          :address_line2,
          :address_postal_code,
          :address_state,
          :contact_email,
          :name
        )

        @sponsor = event.sponsors.new(sponsor)
        authorize @sponsor

        if @sponsor.save
          render :show, status: :created, location: api_v4_sponsor_path(@sponsor)
        else
          return render json: { error: "Could not create a new sponsor." }, status: :unprocessable_entity
        end
      end

    end
  end
end
