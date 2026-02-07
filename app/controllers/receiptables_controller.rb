# frozen_string_literal: true

class ReceiptablesController < ApplicationController
  before_action :set_receiptable
  skip_after_action :verify_authorized # do not force pundit

  def mark_no_or_lost
    authorize @receiptable, policy_class: ReceiptablePolicy

    if @receiptable.no_or_lost_receipt!
      respond_to do |format|
        format.turbo_stream { render turbo_stream: generate_streams }
        format.html do
          flash[:success] = "Marked no/lost receipt on that transaction."
          redirect_to @receiptable
        end
      end
    else
      flash[:error] = "Failed to mark that transaction as no/lost receipt."
      redirect_back(fallback_location: @receiptable)
    end
  end

  private

  RECEIPTABLE_TYPE_MAP = [HcbCode, CanonicalTransaction, Transaction, StripeAuthorization,
                          EmburseTransaction, Reimbursement::Expense, Reimbursement::Expense::Mileage, Reimbursement::Expense::Fee,
                          Api::Models::CardCharge, Ledger::Item].index_by(&:to_s).freeze

  def set_receiptable
    return unless RECEIPTABLE_TYPE_MAP[params[:receiptable_type]]

    @klass = RECEIPTABLE_TYPE_MAP[params[:receiptable_type]]
    @receiptable = @klass.find(params[:receiptable_id])
  end

  def generate_streams
    @frame = params[:popover].present?
    @show_receipt_button = params[:show_receipt_button] == "true"
    @show_author_img = params[:show_author_img] == "true"
    @ledger_instance = params[:ledger_instance]

    streams = []

    receipt_upload_form_config = {
      receiptable: @receiptable,
      enable_linking: true,
      upload_method: "transaction_page",
      include_spacing: true,
      turbo: true
    }

    if @frame
      receipt_upload_form_config[:restricted_dropzone] = true
      receipt_upload_form_config[:inline_linking] = true
      receipt_upload_form_config[:upload_method] = "transaction_popover"
      receipt_upload_form_config[:popover] = "HcbCode:#{@receiptable.hashid}" if @receiptable.is_a?(HcbCode)
      receipt_upload_form_config[:show_receipt_button] = @show_receipt_button
      receipt_upload_form_config[:show_author_img] = @show_author_img
    end

    streams << turbo_stream.replace(
      "#{@receiptable.id}_receipt_upload_form",
      partial: "receipts/form_v3",
      locals: receipt_upload_form_config
    )

    if @receiptable.is_a?(HcbCode)
      @hcb_code = @receiptable

      if !@receiptable.stripe_refund?
        streams << turbo_stream.replace(
          "#{@ledger_instance}_stripe_card_receipts",
          partial: "hcb_codes/stripe_card_receipts"
        )
      end

      if @receiptable.canonical_transactions&.any?
        @receiptable.canonical_transactions.each do |ct|
          streams << turbo_stream.replace(
            ct.local_hcb_code.hashid,
            partial: "canonical_transactions/canonical_transaction",
            locals: @frame ? { ct:, event: @hcb_code.event, show_amount: true, updated_via_turbo_stream: true, show_author_column: @show_author_img, receipt_upload_button: @show_receipt_button } : { ct:, event: @hcb_code.event, force_display_details: true, show_author_column: @show_author_img, receipt_upload_button: @show_receipt_button, show_event_name: true, updated_via_turbo_stream: true }
          )
        end
      else
        @receiptable.canonical_pending_transactions&.each do |pt|
          streams << turbo_stream.replace(
            pt.local_hcb_code.hashid,
            partial: "canonical_pending_transactions/canonical_pending_transaction",
            locals: @frame ? { pt:, event: @hcb_code.event, show_amount: true, updated_via_turbo_stream: true, show_author_column: @show_author_img, receipt_upload_button: @show_receipt_button } : { pt:, event: @hcb_code.event, force_display_details: true, show_author_column: @show_author_img, receipt_upload_button: @show_receipt_button, show_event_name: true, updated_via_turbo_stream: true }
          )
        end
      end
    end

    streams
  end

end
