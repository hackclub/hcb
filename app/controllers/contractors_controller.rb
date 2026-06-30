# frozen_string_literal: true

class ContractorsController < ApplicationController
  include SetEvent

  before_action :set_event

  def new
    authorize @event, policy_class: PaymentPolicy
    @payee = @event.payees.find_by(id: params[:payee_id]) if params[:payee_id].present?
    render layout: "transfer"
  end

  def create
    @payee = @event.payees.find(contractor_params[:payee_id])
    authorize @event, policy_class: PaymentPolicy

    redirect_to event_contractors_path(event_id: @event.slug), notice: "Contractor invited."
  end

  private

  def contractor_params
    params.require(:contractor).permit(:rate, :starts_on, :ends_on, :purpose, :payee_id, file: [])
  end

end
