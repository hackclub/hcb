# frozen_string_literal: true

class Ledger
  class ItemsController < ApplicationController
    before_action :set_item, only: [:pin, :unpin, :edit, :update]

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

    # Renders the "rename transaction" form. Routed as the singular `rename`
    # path (GET), which the router dispatches here.
    def edit
      @event = @item.primary_ledger&.event

      authorize @item

      if params[:inline].present?
        return render partial: "ledger/items/memo/memo", locals: { item: @item, form: true, location: params[:location] }
      end

      # When items/show links here as a turbo frame (matching the frame this
      # renders below), Turbo swaps in just that frame instead of navigating.
      @frame = turbo_frame_request?
    end

    # Handles submission of the "rename transaction" form. Routed as the
    # singular `rename` path (PATCH), which the router dispatches here.
    def update
      authorize @item

      rename_params = params.require(:ledger_item).permit(:memo, :inline, :location)
      @item.update_custom_memo!(rename_params[:memo].presence)

      if rename_params[:inline].present?
        return render partial: "ledger/items/memo/memo", locals: { item: @item, form: false, location: rename_params[:location], renamed: true }
      end

      redirect_to ledger_item_path(@item)
    end

    private

    def set_item
      @item = Ledger::Item.find_by_hashid!(params[:item_id])
    end

  end

end
