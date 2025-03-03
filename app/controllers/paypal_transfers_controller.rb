# frozen_string_literal: true

class PaypalTransfersController < ApplicationController
  include SetEvent

  before_action :set_event, only: %i[new create]
  before_action :set_paypal_transfer, only: %i[approve reject mark_failed]

  def new
    @paypal_transfer = @event.paypal_transfers.build

    authorize @paypal_transfer
  end

  def create
    @paypal_transfer = @event.paypal_transfers.build(paypal_transfer_params.except(:file).merge(user: current_user))

    authorize @paypal_transfer

    if @paypal_transfer.save
      if paypal_transfer_params[:file]
        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments: paypal_transfer_params[:file],
          upload_method: :transfer_create_page,
          receiptable: @paypal_transfer.local_hcb_code
        ).run!
      end
      redirect_to url_for(@paypal_transfer.local_hcb_code), flash: { success: "Your PayPal transfer has been sent!" }
    else
      render "new", status: :unprocessable_entity
    end
  end

  def approve
    authorize @paypal_transfer

    @paypal_transfer.mark_approved!

    redirect_to paypal_transfer_process_admin_path(@paypal_transfer), flash: { success: "Thanks for sending that PayPal transfer." }

  rescue => e
    redirect_to paypal_transfer_process_admin_path(@paypal_transfer), flash: { error: e.message }
  end

  def reject
    authorize @paypal_transfer

    @paypal_transfer.mark_rejected!

    @paypal_transfer.local_hcb_code.comments.create(content: params[:comment], user: current_user, action: :rejected_transfer) if params[:comment]

    redirect_back_or_to paypal_transfer_process_admin_path(@paypal_transfer), flash: { success: "PayPal transfer has been canceled." }
  end

  def mark_failed
    authorize @paypal_transfer

    @paypal_transfer.mark_failed!

    redirect_back_or_to paypal_transfer_process_admin_path(@paypal_transfer), flash: { success: "PayPal transfer has been marked as failed." }
  end

  private

  def paypal_transfer_params
    params.require(:paypal_transfer).permit(
      :memo,
      :amount,
      :payment_for,
      :recipient_name,
      :recipient_email,
      file: []
    )
  end

  def set_paypal_transfer
    @paypal_transfer = PaypalTransfer.find(params[:id])
  end

end
