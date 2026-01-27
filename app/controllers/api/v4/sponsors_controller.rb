# frozen_string_literal: true

module Api
  module V4
    class SponsorsController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:index, :create]

      def index
        authorize @event, :index_in_v4?
        @sponsors = @event.sponsors.order(created_at: :desc)
      end

      def show
        @sponsor = Sponsor.find_by_public_id!(params[:id])
        authorize @sponsor
      end

      def create
        authorize @event

        @sponsor = @event.sponsors.new(sponsor_params)
        authorize @sponsor

        @sponsor.save!
        render :show, status: :created, location: api_v4_sponsor_path(@sponsor)
      end

      private

      def sponsor_params
        params.require(:sponsor).permit(
          :address_city,
          :address_country,
          :address_line1,
          :address_line2,
          :address_postal_code,
          :address_state,
          :contact_email,
          :name
        )
      end

    end
  end
end
