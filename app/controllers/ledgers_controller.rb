# frozen_string_literal: true

class LedgersController < ApplicationController
  def show
    @ledger = Ledger.find_by_hashid!(params[:id])
    authorize @ledger

    @items = Ledger::Query.new({}).execute(ledgers: [@ledger]).order(date: :desc, id: :desc).page(params[:page])
  end

end
