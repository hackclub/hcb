# frozen_string_literal: true

class OrganizerPositionInvite
  class LinksController < ApplicationController
    include SetEvent
    before_action :set_event, only: :create
    before_action :set_link, except: :create

    def show
      authorize @link
    end

    def create
      OrganizerPositionInvite::Link.create!(creator: current_user, event: @event)
    end

    def deactivate
      authorize @link

      @link.deactivate(user: current_user)
    end

    private

    def set_link
      @link = OrganizerPositionInvite::Link.find_by_hashid(params[:id])
    end

  end

end
