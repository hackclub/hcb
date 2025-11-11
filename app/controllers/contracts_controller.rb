# frozen_string_literal: true

class ContractsController < ApplicationController
  before_action :set_opc, only: [:void, :resend_to_user, :resend_to_cosigner]

  def create
    @contract = Contract.new(opc_params)
    authorize @contract
    @contract.save!
    flash[:success] = "Contract sent succesfully."
    redirect_back(fallback_location: event_team_path(@contract.organizer_position_invite.event))
  end

  def void
    authorize @contract
    @contract.mark_voided!
    flash[:success] = "Contract voided succesfully."
    redirect_back(fallback_location: event_team_path(@contract.organizer_position_invite.event))
  end

  def resend_to_user
    authorize @contract

    ContractMailer.with(contract: @contract).notify.deliver_later

    flash[:success] = "Contract resent to user succesfully."
    redirect_back(fallback_location: event_team_path(@contract.organizer_position_invite.event))
  end

  def resend_to_cosigner
    authorize @contract

    if @contract.cosigner_email.present?
      ContractMailer.with(contract: @contract).notify_cosigner.deliver_later
      flash[:success] = "Contract resent to cosigner succesfully."
    else
      flash[:error] = "This contract has no cosigner."
    end

    redirect_back(fallback_location: event_team_path(@contract.organizer_position_invite.event))
  end

  private

  def set_opc
    @contract = Contract.find(params[:id])
  end

  def opc_params
    params.require(:contract).permit(:organizer_position_invite_id, :cosigner_email, :include_videos)
  end

end
