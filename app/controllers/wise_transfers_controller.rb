# frozen_string_literal: true

class WiseTransfersController < ApplicationController
  include SetEvent
  include Admin::TransferApprovable

  before_action :set_event, only: %i[new create]
  before_action :set_wise_transfer, only: %i[update approve reject mark_sent mark_failed]

  def new
    @wise_transfer = @event.wise_transfers.build

    authorize @wise_transfer
    render layout: "transfer"
  end

  def create
    @wise_transfer = @event.wise_transfers.build(wise_transfer_params.except(:file).merge(user: current_user))
    @wise_transfer.recipient_information ||= {}

    authorize @wise_transfer

    if @wise_transfer.amount_cents > 500_00
      return unless enforce_sudo_mode # rubocop:disable Style/SoleNestedConditional
    end

    if @wise_transfer.save
      if wise_transfer_params[:file]
        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments: wise_transfer_params[:file],
          upload_method: :transfer_create_page,
          receiptable: @wise_transfer.local_hcb_code
        ).run!
      end
      redirect_to url_for(@wise_transfer.local_hcb_code), flash: { success: "Your Wise transfer has been sent!" }
    else
      render "new", status: :unprocessable_entity
    end

  end

  def approve
    authorize @wise_transfer
    return unless enforce_sudo_mode

    ensure_admin_may_approve!(@wise_transfer, amount_cents: @wise_transfer.quoted_usd_amount_cents)
    @wise_transfer.mark_approved!

    redirect_to wise_transfer_process_admin_path(@wise_transfer), flash: { success: "You have assigned yourself to this Wise transfer." }
  rescue => e
    redirect_to wise_transfer_process_admin_path(@wise_transfer), flash: { error: e.message }
  end

  def edit
    authorize @wise_transfer
    @event = @wise_transfer.event
  end

  def update
    authorize @wise_transfer
    @event = @wise_transfer.event

    if @wise_transfer.update(wise_transfer_params)
      redirect_to wise_transfer_process_admin_path(@wise_transfer), flash: { success: "Edited the Wise transfer." }
    else
      redirect_to wise_transfer_process_admin_path(@wise_transfer), flash: { error: @wise_transfer.errors.full_messages.to_sentence }
    end
  end

  def mark_sent
    authorize @wise_transfer

    @wise_transfer.assign_attributes(wise_transfer_params)

    begin
      @wise_transfer.mark_sent!
      flash[:success] = "Marked as sent."
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = e.record.errors.full_messages.to_sentence
    end

    redirect_to(wise_transfer_process_admin_path(@wise_transfer))
  end

  def reject
    authorize @wise_transfer

    @wise_transfer.mark_rejected!

    @wise_transfer.local_hcb_code.comments.create(content: params[:comment], user: current_user, action: :rejected_transfer) if params[:comment]

    redirect_back_or_to wise_transfer_process_admin_path(@wise_transfer), flash: { success: "Wire has been canceled." }
  end

  def mark_failed
    authorize @wise_transfer

    @wise_transfer.mark_failed!(params[:reason])

    redirect_back_or_to wise_transfer_process_admin_path(@wise_transfer), flash: { success: "Marked as failed." }
  end

  def generate_quote
    authorize WiseTransfer.new

    money = Money.from_dollars(params[:amount].to_f, params[:currency])
    quote = WiseTransfer.generate_quote(money)

    render plain: quote.format, content_type: "text/plain"
  end

  private

  def wise_transfer_params
    keys = [:memo,
            :amount,
            :payment_for,
            :recipient_name,
            :recipient_email,
            :account_number,
            :institution_number,
            :branch_number,
            :recipient_country,
            :currency,
            :address_line1,
            :address_line2,
            :address_city,
            :address_postal_code,
            :address_state,
            :wise_id,
            :wise_recipient_id,
            { file: [] }] + WiseTransfer.recipient_information_accessors

    keys << :usd_amount if current_user.admin?

    params.require(:wise_transfer).permit(keys)
  end

  def set_wise_transfer
    @wise_transfer = WiseTransfer.find(params[:id])
  end

end
