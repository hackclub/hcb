# frozen_string_literal: true

class Event
  class AffiliationsController < ApplicationController
    # these actions are called before the user has completed their profile during the application process
    skip_before_action :redirect_to_onboarding
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
      redirect_back fallback_location: fallback_location_for(@affiliable)
    end

    def update
      affiliation = Affiliation.find(params[:id])

      authorize affiliation

      affiliation.update(name: params[:type], metadata: @metadata)

      redirect_back fallback_location: fallback_location_for(affiliation.affiliable)
    end

    def destroy
      affiliation = Affiliation.find(params[:id])

      authorize affiliation

      affiliation.destroy!
      redirect_back fallback_location: fallback_location_for(affiliation.affiliable)
    end

    private

    # Used when the request has no referrer. An Event resolves on its own, but
    # Event::Application is routed as `application`, so passing the record
    # straight to `redirect_back` raises NoMethodError (event_application_url).
    def fallback_location_for(affiliable)
      affiliable.is_a?(Event::Application) ? application_path(affiliable) : affiliable
    end

    def set_affiliable
      case params[:affiliable_type]
      when "Event"
        @affiliable = Event.find(params[:affiliable_id])
      when "Event::Application"
        @affiliable = Event::Application.find(params[:affiliable_id])
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
