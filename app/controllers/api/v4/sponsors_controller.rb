# frozen_string_literal: true

module Api
  module V4
    class SponsorsController < ApplicationController
      def index
        @event = Event.find_by_public_id(params[:event_id]) || Event.friendly.find(params[:event_id])
        @sponsors = authorize(@event.sponsors.order(created_at: :desc))
      end

      def show
        # why does this cause "unable to find policy `NilClassPolicy` for `nil`" with a bad id?
        @sponsor = authorize Sponsor.find_by_public_id(params[:id])
      rescue => e
        return render json: { error: e.message }, status: :bad_request
      end

      def create
        event = authorize Event.find_by_public_id(params[:organization_id]) || Event.friendly.find(params[:organization_id])

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

        @sponsor = Sponsor.new(
          address_city: sponsor[:address_city],
          address_country: sponsor[:address_country],
          address_line1: sponsor[:address_line1],
          address_line2: sponsor[:address_line2],
          address_postal_code: sponsor[:address_postal_code],
          address_state: sponsor[:address_state],
          contact_email: sponsor[:contact_email],
          name: sponsor[:name],
          event_id: event.id
        )
        authorize @sponsor

        if @sponsor.save
          render :show
        else
          return render json: { error: e.message }, status: :bad_request
        end
      end

    end
  end
end
