# frozen_string_literal: true

class ContractsController < ApplicationController
  before_action :set_contract, only: [:show, :void, :resend_to_user, :resend_to_cosigner, :contract_signed]
  skip_before_action :signed_in_user, only: [:show, :contract_signed]
  skip_after_action :verify_authorized, only: [:show, :contract_signed]

  def show
    @secret = params[:s]

    begin
      authorize @contract, policy_class: ContractPolicy
    rescue Pundit::NotAuthorizedError
      raise unless Contract.find_signed(@secret, purpose: :cosigner_url) == @contract
    end

    @role = params[:s].present? ? :cosigner : :signee

    @docuseal_url = @role == :cosigner ? @contract.docuseal_cosigner_signature_url : @contract.docuseal_user_signature_url

    if (@role == :signee && @contract.signee_signed?) || (@role == :cosigner && @contract.cosigner_signed?)
      redirect_to contract_signed_contract_path(s: @secret)
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

  def contract_signed
    begin
      authorize @contract, policy_class: ContractPolicy
    rescue Pundit::NotAuthorizedError
      raise unless Contract.find_signed(params[:s], purpose: :cosigner_url) == @contract
    end

    @role = params[:s].present? ? :cosigner : :signee

    if @role == :signee && @contract.signed?
      redirect_to @contract.contractable
      return
    end

    confetti!
  end

  private

  def set_contract
    @contract = Contract.find(params[:id])
  end

end
