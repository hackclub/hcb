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

    @receiptable = @pairing.ledger_item
    @receipt = @pairing.receipt

    if params[:memo] == "true"
      custom_memo = @receipt.suggested_memo
      @receiptable.update_custom_memo!(custom_memo)
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: generate_streams }
      format.html         {
        flash[:success] = { text: "Receipt linked!", link: ledger_item_path(@receiptable), link_text: "View" }
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

    # The item's ledger row, if it's on the page: its receipt count and its
    # receipt buttons (see ledger/items/_receipt_action), like
    # ReceiptsController does after an upload.
    if @receiptable
      @receiptable.reload
      streams.append(turbo_stream.replace([@receiptable, :badges], partial: "ledger/items/badges", locals: { item: @receiptable }))
      streams.append(turbo_stream.replace([@receiptable, :receipt_action], partial: "ledger/items/receipt_action", locals: { item: @receiptable, updated: true }))
    end

    if @receipt
      streams.append(turbo_stream.remove("receipt_#{@receipt.id}"))
      streams.append(turbo_stream.refresh_link_modals)
    end

    streams
  end

end
