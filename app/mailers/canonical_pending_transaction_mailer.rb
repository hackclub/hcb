# frozen_string_literal: true

class CanonicalPendingTransactionMailer < ApplicationMailer
  def notify_approved
    @cpt = CanonicalPendingTransaction.find(params[:canonical_pending_transaction_id])
    @user = @cpt.stripe_card.user

    return unless @user.email_charge_notifications_enabled?

    @upload_url = Rails.application.routes.url_helpers.attach_receipt_hcb_code_url(
      id: @cpt.local_hcb_code.hashid,
      s: @cpt.local_hcb_code.signed_id(expires_in: 2.weeks, purpose: :receipt_upload)
    )

    to = @cpt.stripe_card.user.email_address_with_name
    subject = "#{@cpt.local_hcb_code.receipt_required? ? "Upload a receipt for your transaction" : "New transaction"} at #{@cpt.smart_memo}"
    reply_to = HcbCode.find_or_create_by(hcb_code: @cpt.hcb_code).receipt_upload_email

    mail to:, subject:, reply_to:
  end

  def notify_settled
    @cpt = CanonicalPendingTransaction.find(params[:canonical_pending_transaction_id])
    @ct = CanonicalTransaction.find(params[:canonical_transaction_id])
    @user = @cpt.stripe_card.user

    return unless @user.email_charge_notifications_enabled?

    @upload_url = Rails.application.routes.url_helpers.attach_receipt_hcb_code_url(
      id: @cpt.local_hcb_code.hashid,
      s: @cpt.local_hcb_code.signed_id(expires_in: 2.weeks, purpose: :receipt_upload)
    )

    to = @cpt.stripe_card.user.email_address_with_name
    subject = "#{@cpt.smart_memo} settled at #{ApplicationController.helpers.render_money(@ct.amount)}."
    reply_to = HcbCode.find_or_create_by(hcb_code: @cpt.hcb_code).receipt_upload_email

    mail to:, subject:, reply_to:
  end

  def notify_declined
    @cpt = CanonicalPendingTransaction.find(params[:canonical_pending_transaction_id])
    @card = @cpt.raw_pending_stripe_transaction.stripe_card
    @event = @cpt.event
    @user = @card.user

    return unless @user.email_charge_notifications_enabled?
    return if @card.canceled? && @card.canceled_at < 1.month.ago

    @merchant = @cpt.raw_pending_stripe_transaction.stripe_transaction["merchant_data"]["name"]
    @reason = @cpt.raw_pending_stripe_transaction.stripe_transaction["request_history"][0]&.[]("reason")
    @webhook_declined_reason = @cpt.raw_pending_stripe_transaction.stripe_transaction.dig("metadata", "declined_reason")

    @failed_verification_checks = @cpt.raw_pending_stripe_transaction.stripe_transaction["verification_data"].select { |k, v| k.end_with?("check") && v == "mismatch" }.keys

    mail to: @user.email_address_with_name,
         subject: "Purchase declined at #{@merchant}"
  end

end
