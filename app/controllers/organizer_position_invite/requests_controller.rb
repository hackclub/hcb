# frozen_string_literal: true

class OrganizerPositionInvite
  class RequestsController < ApplicationController
    before_action :set_request, except: :create

    def create
      link = OrganizerPositionInvite::Link.find_by_hashid!(params[:link_id])
      authorize @request = OrganizerPositionInvite::Request.build(requester: current_user, link:)

      @request.save!

      flash[:success] = "Your request has been submitted and is pending approval."
      redirect_to root_path
    end

    def approve
      authorize @request

      link = @request.link
      role = params[:role] || :reader
      enable_spending_controls = (params[:enable_controls] == "true") && (role != "manager")
      initial_control_allowance_amount = params[:initial_control_allowance_amount]

      service = OrganizerPositionInviteService::Create.new(event: link.event, sender: link.creator, user_email: @request.requester.email, is_signee: false, role:, enable_spending_controls:, initial_control_allowance_amount:)

      @invite = service.model

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
