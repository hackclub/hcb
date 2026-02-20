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

    @contract.mark_voided!
    new_contract = Contract.create!(
      contractable: @contract.contractable,
      external_service: @contract.external_service,
      include_videos: @contract.include_videos,
      prefills: @contract.prefills,
      type: @contract.type,
      external_template_id: @contract.external_template_id
    )
    @contract.parties.each do |party|
      new_contract.parties.create!(external_email: party.external_email, role: party.role, user: party.role)
    end
    new_contract.send!

    flash[:success] = "Contract reissued successfully."
    redirect_back(fallback_location: new_contract.redirect_path)
  end

  private

  def set_contract
    @contract = Contract.find(params[:id])
  end

end
