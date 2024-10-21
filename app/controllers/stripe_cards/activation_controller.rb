# frozen_string_literal: true

module StripeCards
  class ActivationController < ApplicationController
    # Form for activating a card
    def new
      @pattern = current_user.stripe_cardholder&.stripe_cards&.where(initially_activated: false)&.first&.id
      skip_authorization
    end

    # Submit a last4 for activation
    def create
      @card = current_user.stripe_cardholder&.stripe_cards&.find_by(last4: params[:last4])

      if @card.nil?
        flash[:error] = "Card not found"
        skip_authorization
        redirect_back fallback_location: new_stripe_cards_activation_path and return
      end

      if @card.canceled?
        flash[:error] = "Card has been cancelled, it can't be activated."
        skip_authorization
        redirect_back fallback_location: new_stripe_cards_activation_path and return
      end

      authorize @card, :activate?

      if @card.initially_activated?
        # Handle cards issued before activation feature launch
        if @card.created_at < Date.new(2024, 2, 22)
          flash[:success] = "Card activated!"
        else
          flash[:error] = "Card already activated"
        end
        redirect_to @card and return
      end

      if @card.replacement_for
        # Does this card replace another card? If so, attempt to cancel the old card
        suppress(Stripe::InvalidRequestError) do
          @card.replacement_for.cancel!
        end
      end

      @card.update(initially_activated: true)
      @card.defrost!

      flash[:success] = "Card activated!"
      redirect_to @card
    end

  end
end
