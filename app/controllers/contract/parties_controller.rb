# frozen_string_literal: true

class Contract
  class PartiesController < ApplicationController
    before_action :set_party
    skip_before_action :signed_in_user, only: [:show, :completed]

    def show
      begin
        authorize @party
      rescue Pundit::NotAuthorizedError
        if signed_in?
          raise
        else
          skip_authorization
          return redirect_to auth_users_path(return_to: contract_party_path(@party)), flash: { info: "To continue, please sign in with the email that you received the invitation with." }
        end
      end

      if @party.signed?
        redirect_to completed_contract_party_path(@party)
        return
      elsif @contract.voided?
        flash[:error] = "This contract has been voided."
        redirect_to root_path
        return
      elsif @contract.pending?
        flash[:error] = "This contract has not been sent yet. Try again later."
        Rails.error.unexpected("Contract not sent, but user is trying to sign it. Party ID: #{@party.id}")
        redirect_to root_path
        return
      end
    end

    def resend
      authorize @party
      @party.notify

      flash[:success] = "Contract resent successfully."
      redirect_back(fallback_location: event_team_path(@contract.event))
    end

    def completed
      authorize @party

      if @party.signee? && @contract.signed?
        redirect_to @contract.contractable
        return
      end

      confetti!
    end

    private

    def set_party
      @party = Contract::Party.find_by_hashid!(params[:id])
      @contract = @party.contract
    end

  end

end
