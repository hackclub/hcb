# frozen_string_literal: true

class Event
  class AffiliationsController < ApplicationController
    before_action :set_affiliable, only: :create
    before_action :set_metadata, only: [:create, :update]

    def create
      authorize @affiliable, policy_class: AffiliationPolicy

      affiliation = Event::Affiliation.new(
        {
          name: params[:type],
          metadata: @metadata,
          affiliable: @affiliable,
        }
      )

      unless affiliation.save
        flash[:error] = affiliation.errors.full_messages.to_sentence.presence || "Failed to create affiliation."
      end
      redirect_back fallback_location: @affiliable
    end

    def update
      affiliation = Affiliation.find(params[:id])

      authorize affiliation

      affiliation.update(name: params[:type], metadata: @metadata)

      redirect_back fallback_location: affiliation.affiliable
    end

    def destroy
      affiliation = Affiliation.find(params[:id])

      authorize affiliation

      affiliation.destroy!
      redirect_back fallback_location: affiliation.affiliable
    end

    private

    def set_affiliable
      case params[:affiliable_type]
      when "Event"
        @affiliable = Event.find(params[:affiliable_id])
      end
    end

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
