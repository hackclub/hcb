# frozen_string_literal: true

class Event
  class AffiliationsController < ApplicationController
    include SetEvent

    before_action :set_event, only: :create
    before_action :set_metadata, only: [:create, :update]

    def create
      authorize @event, policy_class: AffiliationPolicy

      affiliation = @event.affiliations.create(
        {
          name: params[:type],
          metadata: @metadata
        }
      )

      unless affiliation.persisted?
        flash[:error] = affiliation.errors.full_messages.to_sentence.presence || "Failed to create affiliation."
      end
      redirect_back fallback_location: @event
    end

    def update
      affiliation = Affiliation.find(params[:id])

      authorize affiliation

      affiliation.update(name: params[:type], metadata: @metadata)

      redirect_back fallback_location: @event
    end

    def destroy
      affiliation = Affiliation.find(params[:id])

      authorize affiliation

      affiliation.destroy!
      redirect_back fallback_location: @event
    end

    private

    def set_metadata
      case params[:type]
      when "first"
        @metadata = first_params
      when "vex"
        @metadata = vex_params
      when "hack_club"
        @metadata = hack_club_params
      end
    end

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
