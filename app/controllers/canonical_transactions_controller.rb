# frozen_string_literal: true

require "csv"

class CanonicalTransactionsController < ApplicationController
  include TurboStreamFlash
  def show
    @canonical_transaction = CanonicalTransaction.find(params[:id])

    authorize @canonical_transaction

    redirect_to transaction_url(params[:id])
  end

  def edit
    @canonical_transaction = CanonicalTransaction.find(params[:id])

    authorize @canonical_transaction

    @event = @canonical_transaction.event
    @suggested_memos = ::HcbCodeService::SuggestedMemos.new(hcb_code: @canonical_transaction.local_hcb_code, event: @event).run.first(4)
  end

  def set_custom_memo
    @canonical_transaction = CanonicalTransaction.find(params[:id])

    authorize @canonical_transaction

    attributes = params.require(:canonical_transaction).permit(:custom_memo)

    if attributes.key?(:custom_memo)
      custom_memo = attributes[:custom_memo].presence

      # `custom_memo` is mirrored onto the transaction's ledger item, which caches
      # its `memo` from that copy. `HcbCode#update_custom_memo!` is the only writer
      # that keeps both sides in sync; fall back to the ledger item, and only write
      # the column directly when the transaction has neither.
      if (hcb_code = @canonical_transaction.local_hcb_code)
        hcb_code.update_custom_memo!(custom_memo)
      elsif (ledger_item = @canonical_transaction.ledger_item)
        ledger_item.update_custom_memo!(custom_memo)
      else
        @canonical_transaction.update!(custom_memo:)
      end
    end

    unless params[:no_flash]
      flash[:success] = "Renamed transaction"
    end
    redirect_to url_from(params[:redirect_to]) || @canonical_transaction.local_hcb_code
  end

  def set_category
    @canonical_transaction = CanonicalTransaction.find(params[:id])

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

    ct = CanonicalTransaction.find(params[:id])

    fee = ct.fee
    fee.amount_cents_as_decimal = 0
    fee.reason = :revenue_waived
    fee.save!

    redirect_to transaction_url(params[:id])
  end

  def unwaive_fee
    authorize CanonicalTransaction

    ct = CanonicalTransaction.find(params[:id])

    raise ArgumentError unless ct.amount_cents > 0

    fee = ct.fee
    fee.amount_cents_as_decimal = BigDecimal(ct.amount_cents.to_s) * BigDecimal(ct.event.revenue_fee.to_s)

    fee.reason = :revenue
    fee.save!

    redirect_to transaction_url(params[:id])
  end

  def mark_bank_fee
    authorize CanonicalTransaction

    ct = CanonicalTransaction.find(params[:id])

    fee = ct.fee
    fee.reason = :hack_club_fee
    fee.save!

    redirect_to transaction_url(params[:id])
  end

end
