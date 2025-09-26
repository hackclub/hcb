# frozen_string_literal: true

class DisbursementsController < ApplicationController
  before_action :set_disbursement, only: [:show, :edit, :update, :transfer_confirmation_letter]

  def show
    authorize @disbursement

    # Comments
    @hcb_code = HcbCode.find_or_create_by(hcb_code: @disbursement.hcb_code)
  end

  def transfer_confirmation_letter
    authorize @disbursement

    respond_to do |format|
      unless @disbursement.fulfilled?
        redirect_to @disbursement and return
      end

      format.html do
        redirect_to @disbursement
      end

      format.pdf do
        render pdf: "HCB Transfer ##{@disbursement.id} Confirmation Letter (#{@disbursement.source_event.name} to #{@disbursement.destination_event.name} on #{@disbursement.created_at})", page_height: "11in", page_width: "8.5in"
      end

      # not being used at the moment
      format.png do
        send_data ::DocumentPreviewService.new(type: :disbursement_confirmation, disbursement: @disbursement, event: @event).run, filename: "transfer_confirmation_letter.png"
      end

    end
  end

  def new
    @destination_event = Event.friendly.find(params[:event_id]) if params[:event_id]
    @source_event = Event.friendly.find(params[:source_event_id]) if params[:source_event_id]
    @event = @source_event # this is to render the navigation bar for the correct event.
    @disbursement = Disbursement.new(
      destination_event: @destination_event,
      source_event: @source_event,
      amount: params[:amount],
      name: params[:message]
    )

    user_event_ids = current_user.organizer_positions.reorder(sort_index: :asc).pluck(:event_id)

    @allowed_source_events = if admin_signed_in?
                               Event.select(:name, :id, :demo_mode, :slug).all.reorder(Event::CUSTOM_SORT).includes(:plan)
                             else
                               current_user.events.not_hidden.filter_demo_mode(false)
                             end.to_enum.with_index.sort_by { |e, i| [user_event_ids.index(e.id) || Float::INFINITY, i] }.map(&:first)
    @allowed_destination_events = if admin_signed_in?
                                    Event.select(:name, :id, :demo_mode, :can_front_balance, :slug).all.reorder(Event::CUSTOM_SORT).includes(:plan)
                                  elsif @source_event&.plan&.unrestricted_disbursements_enabled?
                                    allowed_destination_event_ids = current_user.events.not_hidden.filter_demo_mode(false).select(:id) + Event.indexable.select(:id)
                                    Event.where(id: allowed_destination_event_ids).select(:name, :id, :demo_mode, :can_front_balance, :slug).includes(:plan)
                                  else
                                    current_user.events.not_hidden.filter_demo_mode(false)
                                  end.to_enum.with_index.sort_by { |e, i| [user_event_ids.index(e.id) || Float::INFINITY, i] }.map(&:first)

    authorize @disbursement
  end

  def create
    @source_event = Event.find_by_public_id(disbursement_params[:source_event_id])
    @destination_event = Event.find_by_public_id(disbursement_params[:event_id]) || Event.friendly.find(disbursement_params[:event_id])
    @disbursement = Disbursement.new(destination_event: @destination_event, source_event: @source_event)

    authorize @disbursement

    if admin_signed_in? && disbursement_params["scheduled_on(1i)"].present?
      scheduled_on = Date.new(disbursement_params["scheduled_on(1i)"].to_i,
                              disbursement_params["scheduled_on(2i)"].to_i,
                              disbursement_params["scheduled_on(3i)"].to_i)
    end

    disbursement = DisbursementService::Create.new(
      name: disbursement_params[:name],
      destination_event_id: @destination_event.id,
      source_event_id: @source_event.id,
      amount: disbursement_params[:amount],
      scheduled_on:,
      requested_by_id: current_user.id,
      should_charge_fee: disbursement_params[:should_charge_fee] == "1",
      fronted: @source_event.plan.front_disbursements_enabled?,
      source_transaction_category_slug: disbursement_params[:source_transaction_category_slug].presence,
      destination_transaction_category_slug: disbursement_params[:destination_transaction_category_slug].presence,
    ).run

    if disbursement_params[:file]
      ::ReceiptService::Create.new(
        uploader: current_user,
        attachments: disbursement_params[:file],
        upload_method: :transfer_create_page,
        receiptable: disbursement.local_hcb_code
      ).run!
    end

    flash[:success] = "Transfer successfully requested."

    if admin_signed_in?
      redirect_to disbursements_admin_index_path
    else
      redirect_to event_transfers_path(@source_event)
    end

  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    flash[:error] = e.message
    redirect_to new_disbursement_path(source_event_id: @source_event)
  rescue ActiveRecord::RecordNotFound => e
    skip_authorization
    flash[:error] = "Organization not found: #{e.id}"
    redirect_to new_disbursement_path(source_event_id: @source_event)
  end

  def edit
    authorize @disbursement
  end

  def update
    authorize @disbursement
  end

  def cancel
    @disbursement = Disbursement.find(params[:disbursement_id])
    authorize @disbursement
    @disbursement.mark_rejected!
    redirect_to @disbursement.local_hcb_code
  end

  def mark_fulfilled
    @disbursement = Disbursement.find(params[:disbursement_id])
    authorize @disbursement

    if @disbursement.mark_in_transit!
      flash[:success] = "Disbursement marked as fulfilled"
      if Disbursement.pending.any?
        redirect_to pending_disbursements_path
      else
        redirect_to disbursements_admin_index_path
      end
    end
  end

  def reject
    @disbursement = Disbursement.find(params[:disbursement_id])
    authorize @disbursement

    begin
      @disbursement.mark_rejected!(current_user)
      flash[:success] = "Disbursement rejected"
    rescue => e
      flash[:error] = e.message
    end

    redirect_to disbursement_path(@disbursement)
  end

  private

  # Only allow a trusted parameter "white list" through.
  def disbursement_params
    attributes = [
      :source_event_id,
      :event_id,
      :amount,
      :name,
      :scheduled_on,
      { file: [] }
    ]

    if admin_signed_in?
      attributes.push(
        :should_charge_fee,
        :source_transaction_category_slug,
        :destination_transaction_category_slug
      )
    end

    params.require(:disbursement).permit(attributes)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_disbursement
    @disbursement = Disbursement.find(params[:id] || params[:disbursement_id])
    @event = @disbursement.event
  end

end
