# frozen_string_literal: true

class Ledger
  # Marks a transaction as a repayment of another on the same ledger, or
  # undoes it. Repayment transfers between organizations live in
  # DisbursementsController.
  class RepaymentsController < ApplicationController
    before_action :set_item

    def create
      authorize @item, :mark_repayment?

      begin
        RepaymentService::Mark.new(ledger_item: @item, other_ledger_item_hashid: params[:other_ledger_item_id], created_by: current_user).run
        flash[:success] = @item.amount_cents.negative? ? "Marked as repaid." : "Marked as a repayment."
      rescue RepaymentService::Mark::UserError => e
        flash[:error] = e.message
      end

      redirect_back fallback_location: @item.hcb_code || @item.primary_ledger&.event
    end

    def destroy
      authorize @item, :unmark_repayment?

      repayment = @item.repaying_repayment || @item.repayments.where.not(repaying_ledger_item_id: nil).first

      if repayment
        RepaymentService::Unmark.new(repayment:).run
        flash[:success] = "Unmarked the repayment."
      else
        flash[:error] = "This transaction isn't marked as a repayment."
      end

      redirect_back fallback_location: @item.hcb_code || @item.primary_ledger&.event
    end

    private

    def set_item
      @item = Ledger::Item.find_by_hashid!(params[:item_id])
    end

  end

end
