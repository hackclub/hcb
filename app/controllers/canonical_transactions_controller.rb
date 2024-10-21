# frozen_string_literal: true

require "csv"

class CanonicalTransactionsController < ApplicationController
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

    @canonical_transaction.update!(params.require(:canonical_transaction).permit(:custom_memo))

    unless params[:no_flash]
      flash[:success] = "Renamed transaction"
    end
    redirect_to params[:redirect_to] || @canonical_transaction.local_hcb_code
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
