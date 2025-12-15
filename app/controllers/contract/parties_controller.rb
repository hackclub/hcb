# frozen_string_literal: true

class Contract
  class PartiesController < ApplicationController
    before_action :set_party
    skip_before_action :signed_in_user, only: [:show, :completed]

    def show
      authorize @party

      if @party.signed?
        redirect_to completed_contract_party_path(@party)
        return
      elsif @contract.voided?
        flash[:error] = "This contract has been voided."
        redirect_to root_path
        return
      elsif @contract.pending?
        flash[:error] = "This contract has not been sent yet. Try again later."
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
      @party = Contract::Party.find_by_hashid(params[:id])
      @contract = @party.contract
    end

  end

end
