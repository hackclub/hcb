# frozen_string_literal: true

module Api
  module V4
    class DonationsController < ApplicationController
      def create
        @event = Event.find_by_public_id(params[:event_id]) || Event.friendly.find(params[:event_id])

        @donation = Donation.new({
                                   amount: params[:amount_cents],
                                   event_id: @event.id,
                                   collected_by_id: current_user.id,
                                   in_person: true,
                                   name: params[:name] || nil,
                                   email: params[:email] || nil
                                 })

        authorize @donation

        @donation.save!

        render "show"
      end

    end
  end
end
