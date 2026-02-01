# frozen_string_literal: true

class Ledger
  class ItemsController < ApplicationController
    def show
      @item = Ledger::Item.find_by_hashid!(params[:id])

      authorize @item
    rescue ActiveRecord::RecordNotFound
      raise unless Transaction.with_deleted.find_by(id: params[:id]).present? || CanonicalTransaction.find_by(id: params[:id]).present?
      skip_authorization
      redirect_to transaction_path(params[:id])
    end
  end

end
