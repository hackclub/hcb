# frozen_string_literal: true

class DisbursementsController < ApplicationController
  before_action :set_disbursement, only: [:show, :edit, :update]

  def index
    @disbursements = Disbursement.all.order(created_at: :desc).includes(:t_transactions, :event, :source_event)
    authorize @disbursements
  end

  def show
    authorize @disbursement

    # Comments
    @hcb_code = HcbCode.find_or_create_by(hcb_code: @disbursement.hcb_code)
  end

  def new
    @destination_event = Event.friendly.find(params[:event_id]) if params[:event_id]
    @source_event = Event.friendly.find(params[:source_event_id]) if params[:source_event_id]
    @disbursement = Disbursement.new(destination_event: @destination_event)

    @allowed_source_events = if current_user.admin?
                               Event.all
                             else
                               [@source_event]
                             end
    @allowed_destination_events = if current_user.admin?
                                    Event.all
                                  else
                                    current_user.events.not_hidden.transparent.where.not(id: @source_event.id)
                                  end

    authorize @destination_event, policy_class: DisbursementPolicy
    authorize @source_event, policy_class: DisbursementPolicy
  end

  def create
    @source_event = Event.friendly.find(disbursement_params[:source_event_id])
    @destination_event = Event.friendly.find(disbursement_params[:event_id])
    authorize @source_event, policy_class: DisbursementPolicy
    authorize @destination_event, policy_class: DisbursementPolicy

    attrs = {
      name: disbursement_params[:name],
      destination_event_id: disbursement_params[:event_id],
      source_event_id: disbursement_params[:source_event_id],
      amount: disbursement_params[:amount],
      requested_by_id: current_user.id
    }
    disbursement = DisbursementService::Create.new(attrs).run

    flash[:success] = "Transfer successfully requested."

    if current_user.admin?
      redirect_to disbursements_admin_index_path
    else
      redirect_to event_transfers_path(event_id: @source_event.id)
    end

  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    flash[:error] = e.message
    redirect_to new_disbursement_path(source_event_id: @source_event)
  end

  def edit
    authorize @disbursement
  end

  def update
    authorize @disbursement
  end

  def mark_fulfilled
    @disbursement = Disbursement.find(params[:disbursement_id])
    authorize @disbursement

    if @disbursement.update(fulfilled_at: DateTime.now)
      flash[:success] = "Disbursement marked as fulfilled"
      if Disbursement.pending.any?
        redirect_to pending_disbursements_path
      else
        redirect_to disbursements_path
      end
    end
  end

  def reject
    @disbursement = Disbursement.find(params[:disbursement_id])
    authorize @disbursement

    if @disbursement.update(rejected_at: DateTime.now)
      flash[:error] = "Disbursement rejected"
      redirect_to disbursements_path
    end
  end

  private

  # Only allow a trusted parameter "white list" through.
  def disbursement_params
    params.require(:disbursement).permit(
      :source_event_id,
      :event_id,
      :amount,
      :name
    )
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_disbursement
    @disbursement = Disbursement.find(params[:id] || params[:disbursement_id])
    @event = @disbursement.event
  end

end
