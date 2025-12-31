# frozen_string_literal: true

class ContractsController < ApplicationController
  def void
    @contract = Contract.find(params[:id])
    authorize @contract, policy_class: ContractPolicy

    @contract.mark_voided!
    flash[:success] = "Contract voided successfully."
    redirect_back(fallback_location: event_team_path(@contract.event))
  end

end
