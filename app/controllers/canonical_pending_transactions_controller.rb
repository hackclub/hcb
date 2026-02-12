# frozen_string_literal: true

class CanonicalPendingTransactionsController < ApplicationController
  include TurboStreamFlash

  before_action :set_canonical_pending_transaction

  def show
    authorize @canonical_pending_transaction

    # Comments
    @hcb_code = HcbCode.find_or_create_by(hcb_code: @canonical_pending_transaction.hcb_code)
  end

  def edit
    authorize @canonical_pending_transaction

    @event = @canonical_pending_transaction.event
    @suggested_memos = ::HcbCodeService::SuggestedMemos.new(hcb_code: @canonical_pending_transaction.local_hcb_code, event: @event).run.first(4)
  end

  def update
    authorize @canonical_pending_transaction

    @canonical_pending_transaction.update!(canonical_pending_transaction_params)

    unless params[:no_flash]
      flash[:success] = "Updated pending transaction"
    end
    redirect_to params[:redirect_to] || @canonical_pending_transaction.local_hcb_code
  end

  def set_category
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

  def set_canonical_pending_transaction
    @canonical_pending_transaction = CanonicalPendingTransaction.find(params[:id])
  end

  def canonical_pending_transaction_params
    if admin_signed_in?
      params.require(:canonical_pending_transaction).permit(:custom_memo, :fronted, :fee_waived)
    else
      params.require(:canonical_pending_transaction).permit(:custom_memo)
    end
  end

end
