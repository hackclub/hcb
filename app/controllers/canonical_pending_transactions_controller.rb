# frozen_string_literal: true

class CanonicalPendingTransactionsController < ApplicationController
  include TurboStreamFlash

  def show
    @canonical_pending_transaction = CanonicalPendingTransaction.find(params[:id])
    authorize @canonical_pending_transaction

    @event = @canonical_pending_transaction.event

    # Comments
    @hcb_code = HcbCode.find_or_create_by(hcb_code: @canonical_pending_transaction.hcb_code)
  end

  def edit
    @canonical_pending_transaction = CanonicalPendingTransaction.find(params[:id])

    authorize @canonical_pending_transaction

    @event = @canonical_pending_transaction.event
    @suggested_memos = ::HcbCodeService::SuggestedMemos.new(hcb_code: @canonical_pending_transaction.local_hcb_code, event: @event).run.first(4)
  end

  def update
    @canonical_pending_transaction = CanonicalPendingTransaction.find(params[:id])

    authorize @canonical_pending_transaction

    attributes = canonical_pending_transaction_params
    renamed = attributes.key?(:custom_memo)
    custom_memo = attributes.delete(:custom_memo).presence

    ActiveRecord::Base.transaction do
      @canonical_pending_transaction.update!(attributes) unless attributes.empty?

      next unless renamed

      # `custom_memo` is mirrored onto the transaction's ledger item, which caches
      # its `memo` from that copy. `HcbCode#update_custom_memo!` is the only writer
      # that keeps both sides in sync; fall back to the ledger item, and only write
      # the column directly when the transaction has neither.
      if (hcb_code = @canonical_pending_transaction.local_hcb_code)
        hcb_code.update_custom_memo!(custom_memo)
      elsif (ledger_item = @canonical_pending_transaction.ledger_item)
        ledger_item.update_custom_memo!(custom_memo)
      else
        @canonical_pending_transaction.update!(custom_memo:)
      end
    end

    unless params[:no_flash]
      flash[:success] = "Updated pending transaction"
    end
    redirect_to url_from(params[:redirect_to]) || @canonical_pending_transaction.local_hcb_code
  end


  def set_category
    @canonical_pending_transaction = CanonicalPendingTransaction.find(params[:id])

    authorize @canonical_pending_transaction

    slug = params.dig(:canonical_pending_transaction, :category_slug)

    TransactionCategoryService
      .new(model: @canonical_pending_transaction)
      .set!(slug:, assignment_strategy: "manual")

    message = "Transaction category was successfully updated."

    respond_to do |format|
      format.turbo_stream do
        flash.now[:success] = message
        update_flash_via_turbo_stream(use_admin_layout: params[:context] == "admin")
      end
      format.html do
        redirect_to(
          canonical_pending_transaction_path(@canonical_pending_transaction),
          flash: { success: message }
        )
      end
    end
  end

  private

  def canonical_pending_transaction_params
    if admin_signed_in?
      params.require(:canonical_pending_transaction).permit(:custom_memo, :fronted, :fee_waived)
    else
      params.require(:canonical_pending_transaction).permit(:custom_memo)
    end
  end

end
