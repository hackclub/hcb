# frozen_string_literal: true

class ContractorsController < ApplicationController
  include SetEvent

  before_action :set_event

  def show
    @contract = @event.payroll_positions.find(params[:id])
    authorize @event, policy_class: ContractorPolicy
    @frame = params[:frame].present?
    @payments = @contract.payee.payments.order(created_at: :desc)
  end

  def new
    authorize @event, policy_class: ContractorPolicy
    @payee = @event.payees.find_by_public_id(params[:payee_id]) if params[:payee_id].present?
    render layout: "transfer"
  end

  def create
    @payee = @event.payees.find_by_public_id!(contractor_params[:payee_id])
    authorize @event, policy_class: ContractorPolicy

    @contract = @payee.payroll_positions.build(
      title: contractor_params[:title],
      rate_cents: (contractor_params[:rate].to_d * 100).to_i,
      start_date: contractor_params[:starts_on],
      end_date: contractor_params[:ends_on],
      description: contractor_params[:purpose]
    )
    if (attachment = Array(contractor_params[:file]).compact_blank.first)
      @contract.file.attach(attachment)
    end

    if @contract.save
      redirect_to event_contractors_path(event_id: @event.slug), notice: "Contractor invited."
    else
      flash.now[:error] = @contract.errors.full_messages.to_sentence
      render :new, layout: "transfer", status: :unprocessable_entity
    end
  end

  private

  def contractor_params
    params.require(:contractor).permit(:title, :rate, :starts_on, :ends_on, :purpose, :payee_id, file: [])
  end

end
