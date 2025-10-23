# frozen_string_literal: true

class HcbCode
  class SubscriptionsController < ApplicationController
    def transactions
      @hcb_code = HcbCode.find_by(hcb_code: params[:id]) || HcbCode.find(params[:id])

      authorize @hcb_code, :show?

      return head :no_content unless @hcb_code.stripe_card?

      @card = @hcb_code.stripe_card

      @subscription = StripeCardService::PredictSubscriptions.new(card: @card).run.detect{ |s| s[:merchant] == @hcb_code.stripe_merchant["name"] }

      return head :no_content unless @subscription

      @hcb_codes = HcbCode.where(id: RawStripeTransaction.where("raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name' = ? AND raw_stripe_transactions.stripe_transaction->>'card' = ?", @hcb_code.stripe_merchant["name"], @card.stripe_id).map { |rst| rst.canonical_transaction.local_hcb_code.id })
    end

  end

end
