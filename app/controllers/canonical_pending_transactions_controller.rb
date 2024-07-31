# frozen_string_literal: true

class CanonicalPendingTransactionsController < ApplicationController
  def show
    @canonical_pending_transaction = CanonicalPendingTransaction.find(params[:id])
    authorize @canonical_pending_transaction

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

    @canonical_pending_transaction.update!(canonical_pending_transaction_params)

    unless params[:no_flash]
      flash[:success] = "Updated pending transaction"
    end
    redirect_to params[:redirect_to] || @canonical_pending_transaction.local_hcb_code
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
