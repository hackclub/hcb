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

      service = OrganizerPositionInviteService::Create.new(event: link.event, sender: current_user, user_email: @request.requester.email, is_signee: false, role:, enable_spending_controls:, initial_control_allowance_amount:, invite_request: @request)

      @invite = service.model

      if service.run
        ActiveRecord::Base.transaction do
          @request.approve!
          @invite.accept
        end
      else
        flash[:error] = service.model.errors.full_messages.to_sentence
      end
      redirect_back_or_to event_team_path(link.event)
    end

    def deny
      authorize @request

      @request.deny!
      redirect_back_or_to event_team_path(@request.link.event)
    end

    private

    def set_request
      @request = OrganizerPositionInvite::Request.find_by_hashid(params[:id])
    end

  end

end
