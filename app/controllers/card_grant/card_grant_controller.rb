# frozen_string_literal: true

class CardGrant
  class CardGrantController < ApplicationController
    before_action :set_card_grant

    def permit_merchant
      authorize @event

      merchant_lock = @event.card_grant_setting.merchant_lock
      if merchant_lock.include?(params[:merchant])
        flash[:error] = "Merchant is already permitted."
        redirect_back fallback_location: edit_event_path(@event.slug, tab: "card_grants") and return
      end

      merchant_lock << params[:merchant]
      @event.card_grant_setting.save!

      flash[:success] = "Merchant successfully permitted."
      redirect_back fallback_location: edit_event_path(@event.slug, tab: "card_grants")
    end
  end

end
