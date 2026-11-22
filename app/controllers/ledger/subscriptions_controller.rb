# frozen_string_literal: true

class Ledger
  # The earlier charges of a subscription, listed on a card charge's ledger
  # item page. HcbCode::SubscriptionsController is the HCB code page's version.
  class SubscriptionsController < ApplicationController
    def transactions
      @item = Ledger::Item.find_by_hashid!(params[:item_id])

      authorize @item, :show?

      return head :no_content unless @item.linked_object_type == "CardCharge"

      @card = @item.linked_object.stripe_card
      merchant_name = @item.linked_object.merchant_data&.dig("name")

      return head :no_content if @card.nil? || merchant_name.nil?

      @subscription = StripeCardService::PredictSubscriptions.new(card: @card).run.detect { |s| s[:merchant] == merchant_name }

      return head :no_content unless @subscription

      # The page (or popover) this list is on already shows @item itself.
      card_charges = CardCharge.joins(:raw_stripe_transactions).where("raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name' = ? AND raw_stripe_transactions.stripe_transaction->>'card' = ?", merchant_name, @card.stripe_id)
      @items = Ledger::Item.where(linked_object_type: "CardCharge", linked_object_id: card_charges.select(:id)).excluding(@item).order(datetime: :desc)

      # Only the full transaction page asks for receipt buttons on the rows. In a
      # popover its upload form doesn't take drops outside itself.
      @receipt_upload = params[:receipt_upload].present?
    end

  end

end
