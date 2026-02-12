# frozen_string_literal: true

require "csv"

class CanonicalTransactionsController < ApplicationController
  include TurboStreamFlash

  before_action :set_canonical_transaction

  def show
    authorize @canonical_transaction

    redirect_to transaction_url(params[:id])
  end

  def edit
    authorize @canonical_transaction

    @event = @canonical_transaction.event
    @suggested_memos = ::HcbCodeService::SuggestedMemos.new(hcb_code: @canonical_transaction.local_hcb_code, event: @event).run.first(4)
  end

  def set_custom_memo
    authorize @canonical_transaction

    @canonical_transaction.update!(params.require(:canonical_transaction).permit(:custom_memo))

    unless params[:no_flash]
      flash[:success] = "Renamed transaction"
    end
    redirect_to params[:redirect_to] || @canonical_transaction.local_hcb_code
  end

  def set_category
    authorize @canonical_transaction

    slug = params.dig(:canonical_transaction, :category_slug)

    TransactionCategoryService
      .new(model: @canonical_transaction)
      .set!(slug:, assignment_strategy: "manual")

    message = "Transaction category was successfully updated."

    respond_to do |format|
      format.turbo_stream do
        flash.now[:success] = message
        update_flash_via_turbo_stream(use_admin_layout: params[:context] == "admin")
      end
      format.html do
        redirect_to(
          canonical_transaction_path(@canonical_transaction),
          flash: { success: message }
        )
      end
    end
  end

  def waive_fee
    authorize CanonicalTransaction

    fee = @canonical_transaction.fee
    fee.amount_cents_as_decimal = 0
    fee.reason = :revenue_waived
    fee.save!

    redirect_to transaction_url(params[:id])
  end

  def unwaive_fee
    authorize CanonicalTransaction

    raise ArgumentError unless @canonical_transaction.amount_cents > 0

    fee = @canonical_transaction.fee
    fee.amount_cents_as_decimal = BigDecimal(@canonical_transaction.amount_cents.to_s) * BigDecimal(@canonical_transaction.event.revenue_fee.to_s)

    fee.reason = :revenue
    fee.save!

    redirect_to transaction_url(params[:id])
  end

  def mark_bank_fee
    authorize CanonicalTransaction

    fee = @canonical_transaction.fee
    fee.reason = :hack_club_fee
    fee.save!

    redirect_to transaction_url(params[:id])
  end

  private

  def set_canonical_transaction
    @canonical_transaction = CanonicalTransaction.find(params[:id])
  end

end
