# frozen_string_literal: true

class PaypalTransfersController < ApplicationController
  include Admin::TransferApprovable

  before_action :set_paypal_transfer, only: %i[approve reject mark_failed]

  def approve
    authorize @paypal_transfer

    ensure_admin_may_approve!(@paypal_transfer, amount_cents: @paypal_transfer.amount_cents)
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

  def set_paypal_transfer
    @paypal_transfer = PaypalTransfer.find(params[:id])
  end

end
