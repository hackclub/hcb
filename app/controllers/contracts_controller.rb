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

    new_contract = nil
    
    ActiveRecord::Base.transaction do
      new_contract = Contract.create!(
        contractable: @contract.contractable,
        external_service: @contract.external_service,
        include_videos: @contract.include_videos,
        prefills: @contract.prefills,
        type: @contract.type,
        external_template_id: @contract.external_template_id
      )

      @contract.parties.not_hcb.each do |party|
        new_contract.parties.create!(external_email: party.external_email, role: party.role, user: party.user)
      end
    end

    new_contract.send!(reissue_signee_message: signee_message, reissue_cosigner_message: cosigner_message)

    flash[:success] = "Contract reissued successfully."
    redirect_to new_contract.redirect_path
  rescue => e
    Rails.error.report(e)
    flash[:error] = "Failed to reissue contract."
    redirect_to new_contract.redirect_path
  end

  private

  def set_contract
    @contract = Contract.find(params[:id])
  end

end
