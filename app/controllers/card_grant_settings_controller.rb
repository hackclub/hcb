# frozen_string_literal: true

class CardGrantSettingsController < ApplicationController
  def update
    card_grant_setting = CardGrantSetting.find(params[:id])
    authorize card_grant_setting
    card_grant_setting.update!(card_grant_setting_params)
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
