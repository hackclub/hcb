# frozen_string_literal: true

class Ledger
  class ItemsController < ApplicationController
    def show
      @item = Ledger::Item.find_by_hashid!(params[:id])

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

  end

end
