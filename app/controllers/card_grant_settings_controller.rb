# frozen_string_literal: true

class CardGrantSettingsController < ApplicationController
  def update
    card_grant_setting = CardGrantSetting.find(params[:id])
    authorize card_grant_setting
    if card_grant_setting.update(card_grant_setting_params)
      flash[:success] = "Card grant settings updated."
    else
      flash[:error] = card_grant_setting.errors.full_messages.to_sentence
    end
    redirect_back_or_to edit_event_path(card_grant_setting.event.slug, tab: "card_grants")
  end

  private

  def card_grant_setting_params
    params.require(:card_grant_setting).permit(
      :merchant_lock,
      { category_lock: [] },
      :keyword_lock,
      :invite_message,
      :banned_merchants,
      { banned_categories: [] },
      :expiration_preference,
      :reimbursement_conversions_enabled,
      :pre_authorization_required,
      :block_suspected_fraud,
      :support_message,
      :support_url
    )
  end

end
