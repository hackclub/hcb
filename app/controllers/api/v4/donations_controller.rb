# frozen_string_literal: true

module Api
  module V4
    class DonationsController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:create]

      def create
        @donation = Donation.new({
                                   amount: params[:amount_cents],
                                   event_id: @event.id,
                                   collected_by_id: current_user.id,
                                   in_person: true,
                                   name: params[:name].presence,
                                   email: params[:email].presence,
                                   anonymous: params[:anonymous].presence,
                                   tax_deductible: params[:tax_deductible].presence,
                                   fee_covered: params[:fee_covered].presence && @event.config.cover_donation_fees
                                 })

        authorize @donation

        @donation.save!

        render "show", status: :created
      end

    end
  end
end
