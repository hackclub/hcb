# frozen_string_literal: true

class Ledger
  class ItemsController < ApplicationController
    before_action :set_pin, only: [:pin, :unpin]

    def show
      @item = Ledger::Item.find_by_hashid!(params[:id])

      # Non-engineers see the user-facing HCB code page rather than the raw
      # ledger item. hcb_codes#show performs its own authorization.
      unless FlipperGroups.hcb_engineer?(current_user) || Rails.env.development?
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

    def pin
      @event = @item.primary_ledger&.event

      authorize @item
      authorize @event

      if @item.primary_mapping&.pin
        flash[:success] = "Transaction pinned!"
      else
        flash[:error] = @item.primary_mapping&.errors&.full_messages&.to_sentence || "At the moment, this transaction can't be pinned."
      end

      redirect_back fallback_location: @event
    end

    def unpin
      @event = @item.primary_ledger&.event

      authorize @item
      authorize @event

      if @item.primary_mapping&.unpin
        flash[:success] = "Unpinned transaction from #{@event&.name}"
      else
        flash[:error] = "There was an error in unpinning this transaction."
        Rails.error.unexpected "There was an error in unpinning ledger item #{@item.hashid}"
      end

      redirect_back fallback_location: @event
    end

    private

    def set_pin
      @item = Ledger::Item.find_by_hashid!(params[:item_id])
    end

  end

end
