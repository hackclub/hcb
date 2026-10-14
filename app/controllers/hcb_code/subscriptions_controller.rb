# frozen_string_literal: true

class HcbCode
  class SubscriptionsController < ApplicationController
    before_action :set_hcb_code

    def transactions
      authorize @hcb_code, :show?

      return head :no_content unless @hcb_code.stripe_card?

      @card = @hcb_code.stripe_card

      if @hcb_code.subscription.present? && policy(@hcb_code.subscription).show?
        @stored_subscription = @hcb_code.subscription
        @hcb_codes = @stored_subscription.hcb_codes.where.not(id: @hcb_code.id)

        return
      end

      @subscription = StripeCardService::PredictSubscriptions.new(card: @card).run.detect{ |s| s[:merchant] == @hcb_code.stripe_merchant["name"] }

      return head :no_content unless @subscription

      @hcb_codes = HcbCode.where(id: RawStripeTransaction.where("raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name' = ? AND raw_stripe_transactions.stripe_transaction->>'card' = ?", @hcb_code.stripe_merchant["name"], @card.stripe_id).map { |rst| rst.canonical_transaction.local_hcb_code.id })
    end

    def create
      authorize @hcb_code, :show?

      stripe_card = @hcb_code.stripe_card
      merchant = @hcb_code.subscription_merchant
      raise Pundit::NotAuthorizedError unless @hcb_code.card_charge? && stripe_card.present? && merchant.present? && @hcb_code.amount_cents.negative?

      subscription = Subscription.new(
        event: stripe_card.event,
        stripe_card:,
        created_by: current_user,
        source: :manual,
        merchant_network_id: merchant[:network_id],
        merchant_name: merchant[:name] || merchant[:network_id],
        name: params.dig(:subscription, :name).presence || Subscription.humanized_merchant_name(**merchant),
        amount_cents: @hcb_code.amount_cents.abs,
        cadence: params.dig(:subscription, :cadence),
        cadence_days: params.dig(:subscription, :cadence_days)
      )
      authorize subscription

      if @hcb_code.subscription_id.present?
        flash[:error] = "This transaction is already part of a subscription."
      elsif subscription.save
        subscription.link!(@hcb_code)
        flash[:success] = "Marked as a subscription."
      else
        flash[:error] = subscription.errors.full_messages.to_sentence
      end

      redirect_back_or_to hcb_code_path(@hcb_code)
    end

    private

    def set_hcb_code
      @hcb_code = HcbCode.find_by(hcb_code: params[:id]) || HcbCode.find(params[:id])
    end

  end

end
