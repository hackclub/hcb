# frozen_string_literal: true

class OrganizerPositionInvite
  class RequestsController < ApplicationController
    before_action :set_request, except: :create

    def create
      OrganizerPositionInvite::Request.create!(requester: current_user, organizer_position_invite_link: OrganizerPositionInvite::Link.find_by_hashid!(params[:id]))

      redirect_to root_path
    end

    def approve
      service = OrganizerPositionInviteService::Create.new(event: link.event, sender: link.creator, user_email: requester.email, is_signee: false, role: params[:role], enable_spending_controls: params[:enable_spending_controls], initial_control_allowance_amount: params[:initial_control_allowance_amount])

      @invite = service.model

      authorize @invite

      if service.run
        @invite.accept
        @request.approve!

      else
        flash[:error] = service.model.errors.full_messages.to_sentence
        redirect_back_or_to event_team_path(link.event)
      end
    end

    def deny
      authorize @request

      @request.deny!
    end

    private

    def set_request
      @request = OrganizerPositionInvite::Request.find_by_hashid(params[:id])
    end

  end

end
