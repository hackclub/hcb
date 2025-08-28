# frozen_string_literal: true

class Event
  class AffiliationsController < ApplicationController
    include SetEvent

    before_action :set_event, only: :create

    def create
      authorize @event, policy_class: AffiliationPolicy

      case params[:type]
      when "first"
        metadata = first_params
      when "vex"
        metadata = vex_params
      when "hack_club"
        metadata = hack_club_params
      end

      @event.affiliations.create({
        name: params[:type],
        metadata:
      })
    end

    def update
      authorize @affiliation
    end

    def destroy
      authorize @affiliation
    end

    private

    def first_params
      params.permit(:league, :team_number, :size)
    end

    def vex_params
      params.permit(:league, :team_number, :size)
    end

    def hack_club_params
      params.permit(:venue_name, :size)
    end

  end

end
