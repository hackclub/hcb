# frozen_string_literal: true

class Ledger
  # Marks money in as a repayment of expenses on the same ledger. Repayment transfers between organizations live in
  # DisbursementsController.
  class RepaymentsController < ApplicationController
    before_action :set_item

    CANDIDATES_PER_PAGE = 25

    # Rows for the picker: the transactions this one could be matched with.
    def candidates
      authorize @item, :mark_repayment?

      @candidates = Repayment.match_candidates(@item, current_user).order(datetime: :desc).page(params[:page]).per(CANDIDATES_PER_PAGE)

      render layout: false
    end

    def create
      authorize @item, :mark_repayment?

      begin
        RepaymentService::Mark.new(ledger_item: @item, other_ledger_item_hashids: params[:other_ledger_item_ids], created_by: current_user).run
        flash[:success] = @item.amount_cents.negative? ? "Marked as repaid." : "Marked as a repayment."
      rescue RepaymentService::Mark::UserError => e
        flash[:error] = e.message
      end

      redirect_back fallback_location: @item.hcb_code || @item.primary_ledger&.event
    end

    private

    def set_item
      @item = Ledger::Item.find_by_hashid!(params[:item_id])
    end

  end

end
