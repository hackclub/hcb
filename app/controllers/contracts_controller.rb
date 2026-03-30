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

    signee_message = params[:signee_message].presence
    cosigner_message = params[:cosigner_message].presence

    unless signee_message.present? || cosigner_message.present?
      redirect_back_or_to contract_party_path(@contract.party(:hcb)), flash: { error: "You must provide a message for the signee, cosigner, or both." }
      return
    end

    @contract.mark_voided!
    new_contract = @contract.contractable.send_contract(
      cosigner_email: @contract.party(:cosigner)&.email,
      include_videos: @contract.include_videos,
      reissue_signee_message: signee_message,
      reissue_cosigner_message: cosigner_message
    )

    flash[:success] = "Contract reissued successfully."
    redirect_to new_contract.redirect_path
  rescue => e
    Rails.error.report(e)
    flash[:error] = "Failed to reissue contract."
    redirect_to @contract.redirect_path
  end

  private

  def set_contract
    @contract = Contract.find(params[:id])
  end

end
