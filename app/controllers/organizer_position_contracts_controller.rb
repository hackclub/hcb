# frozen_string_literal: true

class OrganizerPositionContractsController < ApplicationController
  before_action :set_opc, only: [:void]

  def create
    @contract = OrganizerPosition::Contract.new(opc_params)
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

  private

  def set_opc
    @contract = OrganizerPosition::Contract.find(params[:id])
  end

  def opc_params
    params.require(:organizer_position_contract).permit(:organizer_position_invite_id, :cosigner_email, :include_videos)
  end

end
