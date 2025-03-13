# frozen_string_literal: true

class AchTransfersController < ApplicationController
  include SetEvent

  before_action :set_ach_transfer, except: [:new, :create, :index, :validate_routing_number]
  before_action :set_event, only: [:new, :create]
  skip_before_action :signed_in_user, except: [:validate_routing_number]
  skip_after_action :verify_authorized, only: [:validate_routing_number]

  # GET /ach_transfers/1
  def show
    authorize @ach_transfer

    redirect_to @ach_transfer.local_hcb_code
  end

  def transfer_confirmation_letter
    authorize @ach_transfer

    respond_to do |format|
      unless @ach_transfer.deposited?
        redirect_to @ach_transfer and return
      end

      format.html do
        redirect_to @ach_transfer
      end

      format.pdf do
        render pdf: "ACH Transfer ##{@ach_transfer.id} Confirmation Letter (#{@event.name} to #{@ach_transfer.recipient_name} on #{@ach_transfer.canonical_pending_transaction.date.strftime("%B #{@ach_transfer.canonical_pending_transaction.date.day.ordinalize}, %Y")})", page_height: "11in", page_width: "8.5in"
      end

      # works, but not being used at the moment
      format.png do
        send_data ::DocumentPreviewService.new(type: :ach_transfer_confirmation, ach_transfer: @ach_transfer, event: @event).run, filename: "transfer_confirmation_letter.png"
      end

    end
  end

  # GET /ach_transfers/new
  def new
    @ach_transfer = AchTransfer.new(event: @event)
    authorize @ach_transfer
  end

  # POST /ach_transfers
  def create
    @ach_transfer = @event.ach_transfers.build(ach_transfer_params.except(:file).merge(creator: current_user))

    authorize @ach_transfer

    if @ach_transfer.save
      if ach_transfer_params[:file]
        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments: ach_transfer_params[:file],
          upload_method: :transfer_create_page,
          receiptable: @ach_transfer.local_hcb_code
        ).run!
      end
      redirect_to event_transfers_path(@event), flash: { success: "ACH transfer successfully submitted." }
    else
      render :new, status: :unprocessable_entity
    end
  end

  def cancel
    authorize @ach_transfer

    @ach_transfer.mark_rejected!

    redirect_to @ach_transfer.local_hcb_code
  end

  def toggle_speed
    authorize @ach_transfer
    @ach_transfer.toggle!(:same_day)
    redirect_back_or_to ach_start_approval_admin_path(@ach_transfer)
  end

  def validate_routing_number
    return render json: { valid: true } if params[:value].empty?
    return render json: { valid: false, hint: "Bank not found for this routing number." } unless /\A\d{9}\z/.match?(params[:value])

    bank = ColumnService.get "/institutions/#{params[:value]}" # This is safe since params[:value] is validated to only contain digits above

    if bank["routing_number_type"] != "aba"
      render json: {
        valid: false,
        hint: "Please enter an ABA routing number."
      }
    elsif bank["ach_eligible"] == false
      render json: {
        valid: false,
        hint: "This routing number cannot accept ACH transfers."
      }
    else
      render json: {
        valid: true,
        hint: bank["full_name"].titleize,
      }
    end
  rescue Faraday::BadRequestError
    return render json: { valid: false, hint: "Bank not found for this routing number." }
  rescue => e
    Rails.error.report(e)
    render json: { valid: true }
  end

  private

  def set_ach_transfer
    @ach_transfer = AchTransfer.find(params[:id] || params[:ach_transfer_id])
    @event = @ach_transfer.event
  end

  def ach_transfer_params
    permitted_params = [:routing_number, :account_number, :recipient_email, :bank_name, :recipient_name, :amount_money, :payment_for, :send_email_notification, { file: [] }, :payment_recipient_id]

    if admin_signed_in?
      permitted_params << :scheduled_on
    end

    params.require(:ach_transfer).permit(*permitted_params)
  end

end
