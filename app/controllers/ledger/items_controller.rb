# frozen_string_literal: true

class Ledger
  class ItemsController < ApplicationController
    def show
      @item = Ledger::Item.find_by_hashid!(params[:id])

      # Non-engineers see the user-facing HCB code page rather than the raw
      # ledger item. hcb_codes#show performs its own authorization.
      unless FlipperGroups.hcb_engineer?(current_user)
        skip_authorization
        return redirect_to hcb_code_path(@item.hcb_code)
      end

      authorize @item
    rescue ActiveRecord::RecordNotFound
      # Maintain backward compatibility for old v1 transaction engine URLs. They
      # used to also live at `/transactions/*`
      if Transaction.with_deleted.where(id: params[:id]).exists? || CanonicalTransaction.where(id: params[:id]).exists?
        skip_authorization
        return redirect_to transaction_path(params[:id])
      end

      raise
    end

    def hcb
      @item = Ledger::Item.find_by_hashid!(params[:item_id])

      authorize @item

      redirect_to hcb_code_path(@item.hcb_code)
    end

  end

end
