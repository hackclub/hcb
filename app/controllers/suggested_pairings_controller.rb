# frozen_string_literal: true

class SuggestedPairingsController < ApplicationController
  def ignore
    @pairing = SuggestedPairing.find(params[:id])
    authorize @pairing

    @pairing.mark_ignored!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: generate_streams }
      format.html         {
        flash[:success] = "Suggestion ignored"
        redirect_back fallback_location: my_inbox_path
      }
    end
  end

  def accept
    @pairing = SuggestedPairing.find(params[:id])
    authorize @pairing

    @pairing.mark_accepted!

    @receiptable = @pairing.hcb_code
    @receipt = @pairing.receipt

    if params[:memo] == "true"
      custom_memo = @receipt.suggested_memo
      @receiptable.canonical_transactions.each { |ct| ct.update!(custom_memo:) }
      @receiptable.canonical_pending_transactions.each { |cpt| cpt.update!(custom_memo:) }
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: generate_streams }
      format.html         {
        flash[:success] = { text: "Receipt linked!", link: hcb_code_path(@pairing.hcb_code), link_text: "View" }
        redirect_back fallback_location: my_inbox_path
      }
    end
  end

  def generate_streams
    streams = []

    pairings = current_user.receipt_bin.suggested_receipt_pairings

    current_slide = [pairings.size - 1, Integer(params[:current_slide] || 0)].min

    streams.append(
      turbo_stream.replace(
        "suggested_pairings",
        partial: "static_pages/suggested_pairings",
        locals: { pairings:, current_slide: }
      )
    )

    if @receiptable
      if @receiptable.canonical_transactions&.any?
        @receiptable.canonical_transactions.each do |ct|
          streams.append(turbo_stream.replace(
                           ct.local_hcb_code.hashid,
                           partial: "canonical_transactions/canonical_transaction",
                           locals: { ct:, force_display_details: true, receipt_upload_button: true, show_event_name: true, updated_via_turbo_stream: true }
                         ))
        end
      else
        @receiptable.canonical_pending_transactions&.each do |pt|
          streams.append(turbo_stream.replace(
                           pt.local_hcb_code.hashid,
                           partial: "canonical_pending_transactions/canonical_pending_transaction",
                           locals: { pt:, force_display_details: true, receipt_upload_button: true, show_event_name: true, updated_via_turbo_stream: true }
                         ))
        end
      end
    end

    if @receipt
      streams.append(turbo_stream.remove("receipt_#{@receipt.id}"))
      streams.append(turbo_stream.refresh_link_modals)
    end

    streams
  end

end
