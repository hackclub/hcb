# frozen_string_literal: true

class ContractsController < ApplicationController
  before_action :set_contract, only: [:void, :resend_to_user, :resend_to_cosigner]

  def create
    @contract = Contract.new(contract_params)
    authorize @contract, policy_class: ContractPolicy
    @contract.save!
    flash[:success] = "Contract sent successfully."
    redirect_back(fallback_location: event_team_path(@contract.event))
  end

  def void
    authorize @contract, policy_class: ContractPolicy
    @contract.mark_voided!
    flash[:success] = "Contract voided successfully."
    redirect_back(fallback_location: event_team_path(@contract.event))
  end

  def resend_to_user
    authorize @contract, policy_class: ContractPolicy

    ContractMailer.with(contract: @contract).notify.deliver_later

    flash[:success] = "Contract resent to user successfully."
    redirect_back(fallback_location: event_team_path(@contract.event))
  end

  def resend_to_cosigner
    authorize @contract, policy_class: ContractPolicy

    if @contract.cosigner_email.present?
      ContractMailer.with(contract: @contract).notify_cosigner.deliver_later
      flash[:success] = "Contract resent to cosigner successfully."
    else
      flash[:error] = "This contract has no cosigner."
    end

    redirect_back(fallback_location: event_team_path(@contract.event))
  end

  private

  def set_contract
    @contract = Contract.find(params[:id])
  end

  def contract_params
    params.require(:contract).permit(:type, :contractable_id, :contractable_type, :cosigner_email, :include_videos)
  end

end
