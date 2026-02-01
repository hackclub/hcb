# frozen_string_literal: true

class Ledger
  class ItemsController < ApplicationController
    def show
      @item = Ledger::Item.find_by_hashid!(params[:id])

      authorize @item
    end
  end

end
