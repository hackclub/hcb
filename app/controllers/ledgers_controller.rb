# frozen_string_literal: true

class LedgersController < ApplicationController
  def show
    @ledger = Ledger.find_by_hashid!(params[:id])
    authorize @ledger

    # TODO: Replace with Ledger::Query
    @items = @ledger.items.order(datetime: :desc, created_at: :desc, id: :desc).page(params[:page])
  end

end
