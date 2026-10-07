# frozen_string_literal: true

class ContractsController < ApplicationController
  before_action :set_contract

  def void
    authorize @contract, policy_class: ContractPolicy

    @contract.mark_voided!
    flash[:success] = "Contract voided successfully."
    redirect_back(fallback_location: @contract.redirect_path)
  end

  def reissue
    authorize @contract, policy_class: ContractPolicy

    reissue_messages = reissue_messages_params

    unless reissue_messages.values.any?(&:present?)
      redirect_back_or_to contract_party_path(@contract.party(:hcb)), flash: { error: "You must provide a message for at least one party." }
      return
    end

    @contract.mark_voided!(reissuing: true)
    new_contract = @contract.contractable.send_contract(
      cosigner_email: @contract.party(:cosigner)&.email,
      include_videos: @contract.include_videos,
      reissue_messages:,
      reissue_of: @contract
    )

    flash[:success] = "Contract reissued successfully."
    redirect_to new_contract.redirect_path
  rescue => e
    Rails.error.report(e)
    flash[:error] = "Failed to reissue contract."
    redirect_to @contract.redirect_path
  end

  private

  def reissue_messages_params
    permitted_roles = @contract.parties.not_hcb.map(&:role)
    params.fetch(:reissue_messages, ActionController::Parameters.new).permit(*permitted_roles).to_h
  end

  def set_contract
    @contract = Contract.find(params[:id])
  end

end
