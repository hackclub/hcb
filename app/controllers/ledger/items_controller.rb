# frozen_string_literal: true

class Ledger
  class ItemsController < ApplicationController
    before_action :set_item, except: [:show]

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

    def rename
      authorize @item

      memo = params.require(:ledger_item).permit(:memo)[:memo].presence
      @item.update_custom_memo!(memo)

      render partial: "ledger/items/memo/stream", locals: { item: @item }, formats: :turbo_stream
    end

    def invoice_as_personal_transaction
      authorize @item

      personal_tx = PersonalTransaction.new(ledger_item: @item, reporter: current_user)

      if personal_tx.save
        flash[:success] = "We've sent an invoice for repayment to #{personal_tx.invoice.sponsor.contact_email}."
        return redirect_to personal_tx.invoice
      end

      if @item.personal_transaction.present?
        flash[:error] = "A repayment invoice already exists for this transaction."
        redirect_to @item.personal_transaction.invoice
      else
        flash[:error] = personal_tx.errors.full_messages.to_sentence
        redirect_to @item.hcb_code
      end
    end

    private

    def set_item
      @item = Ledger::Item.find_by_hashid!(params[:item_id])
    end

  end

end
