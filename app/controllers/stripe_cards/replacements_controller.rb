# frozen_string_literal: true

module StripeCards
  class ReplacementsController < ApplicationController
    before_action :set_stripe_card
    before_action :set_dispute
    before_action :set_flow, only: :new
    before_action :set_reason, only: :create

    def new
      authorize @stripe_card, :replace?

      @step = @flow.find_step(params[:step])

      render layout: false
    end

    def create
      authorize @stripe_card, :replace?

      replacement = ::StripeCardService::Replace.new(
        stripe_card: @stripe_card,
        reason: @reason,
        ip_address: current_session.ip,
        shipping_address: params.fetch(:shipping_address, {}).permit(:name, :line1, :line2, :city, :state, :postal_code).to_h
      ).run

      flash[:success] = success_message(replacement)
      redirect_to @dispute ? dispute_hcb_code_path(@dispute) : replacement
    rescue ::StripeCardService::Replace::InvalidShippingAddressError => e
      redirect_to @stripe_card, flash: { error: e.message }
    rescue ::StripeCardService::Replace::OrderFailedError => e
      Rails.error.report(e)
      redirect_to @stripe_card, flash: { error: "Your card was canceled, but we couldn't order its replacement. Please contact hcb@hackclub.com and we'll sort it out." }
    rescue Pundit::NotAuthorizedError
      raise
    rescue => e
      Rails.error.report(e)
      redirect_to @stripe_card, flash: { error: "We couldn't replace your card. Your current card hasn't been changed." }
    end

    private

    def success_message(replacement)
      if ::StripeCardService::Replace::CANCEL_FIRST_REASONS.include?(@reason)
        if replacement.virtual?
          "Your card was canceled, and your replacement card with a new card number is ready to use."
        else
          "Your card was canceled, and your replacement card is on its way. Activate it once it arrives."
        end
      elsif replacement.virtual?
        "Your replacement card is ready to use, and your old card has been canceled."
      else
        "Your replacement card is on its way! Your current card will keep working until you activate the new one."
      end
    end

    def set_stripe_card
      @stripe_card = StripeCard.find(params[:stripe_card_id])
    end

    def set_flow
      unless StripeCard::ReplacementFlow.supported?(params[:flow])
        skip_authorization
        raise ActionController::BadRequest, "Unsupported replacement flow"
      end

      @flow = StripeCard::ReplacementFlow.new(stripe_card: @stripe_card, flow: params[:flow], reason: params[:reason], dispute: @dispute)
    end

    def set_dispute
      return if params[:dispute].blank?

      hcb_code = HcbCode.find_by_hashid(params[:dispute])
      @dispute = hcb_code if hcb_code&.stripe_card == @stripe_card
    end

    def set_reason
      unless ::StripeCardService::Replace::REASONS.include?(params[:reason])
        skip_authorization
        raise ActionController::BadRequest, "Unsupported replacement reason"
      end

      @reason = params[:reason]
    end

  end
end
