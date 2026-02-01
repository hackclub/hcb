# frozen_string_literal: true

class Ledger
  class ItemsController < ApplicationController
    def show
      @item = Ledger::Item.find(params[:id])

      authorize @item
    end

    def comment
      @item = Ledger::Item.find(params[:id])

      authorize @item

      @item.comments.create!(
        content: params[:content],
        file: params[:file],
        admin_only: params[:admin_only] || false,
        user: current_user
      )

      redirect_to params[:redirect_url]
    rescue => e
      redirect_to params[:redirect_url], flash: { error: e.message }
    end
  end

end
