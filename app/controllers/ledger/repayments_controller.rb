# frozen_string_literal: true

class Ledger
  # Marks a transaction as a repayment of another on the same ledger. Repayment transfers between organizations live in
  # DisbursementsController.
  class RepaymentsController < ApplicationController
    before_action :set_item

    CANDIDATES_PER_PAGE = 25

    # Rows for the picker: the transactions this one could be matched with.
    def candidates
      authorize @item, :mark_repayment?

      # The rows are ledger/_item, which reads these per item (see Ledger::Query#execute);
      # the author column is off, so the author isn't needed.
      @candidates = Repayment.match_candidates(@item, current_user)
                             .order(datetime: :desc)
                             .preload(:linked_object, :tags, :hcb_code, primary_ledger: [:event, { card_grant: :event }])
                             .page(params[:page]).per(CANDIDATES_PER_PAGE)

      render layout: false
    end

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

    private

    def set_item
      @item = Ledger::Item.find_by_hashid!(params[:item_id])
    end

  end

end
