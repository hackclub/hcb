# frozen_string_literal: true


class PayoutMethodsController < ApplicationController
  before_action :require_multiple_payout_methods
  before_action :authorize_payout_edit
  before_action :require_unlocked_payout
  before_action :set_payout_method, only: [:update, :set_default, :destroy]

  def create
    service = LegalEntity::PayoutMethodService::Update.new(
      user: current_user,
      details_type: params.dig(:user, :payout_method_type),
      details_attrs: details_params_for(params.dig(:user, :payout_method_type)),
      make_default: legal_entity.payout_methods.none?
    )

    if service.run
      flash[:success] = "Payout method added."
      redirect_back_or_to settings_payouts_path
    else
      render_payout_settings(service.payout_method)
    end
  end

  def update
    @payout_method.details.assign_attributes(details_params_for(@payout_method.details_type))

    if @payout_method.save
      flash[:success] = "Payout method updated."
      redirect_back_or_to settings_payouts_path
    else
      render_payout_settings(@payout_method)
    end
  end

  def set_default
    @payout_method.update!(default: true)
    flash[:success] = "Default payout method updated."
    redirect_back_or_to settings_payouts_path
  end

  def destroy
    was_default = @payout_method.default?
    @payout_method.destroy!

    if was_default
      legal_entity.payout_methods.order(created_at: :desc).first&.update!(default: true)
    end

    flash[:success] = "Payout method removed."
    redirect_back_or_to settings_payouts_path
  end

  private

  # The multi-method payout UI (and these endpoints) only exist behind the
  # flag; without it, payout methods are managed through users#update.
  def require_multiple_payout_methods
    return if Flipper.enabled?(:multiple_payout_methods_2026_06_26, current_user)

    skip_authorization
    redirect_to settings_payouts_path
  end

  def authorize_payout_edit
    authorize current_user, :edit_payout?
  end

  def require_unlocked_payout
    payout_locked!
  end

  def render_payout_settings(payout_method)
    @user = current_user
    @payout_method = payout_method
    flash.now[:error] = payout_method.error_messages.to_sentence

    lookup_context.prefixes.unshift("users")
    render template: "users/edit_payout", status: :unprocessable_entity
  end

  def legal_entity
    current_user.personal_legal_entity
  end

  def set_payout_method
    @payout_method = legal_entity&.payout_methods&.find_by(id: params[:id])
    return if @payout_method

    skip_authorization
    flash[:error] = "Payout method not found."
    redirect_back_or_to settings_payouts_path
  end

  def details_params_for(type_name)
    root = params.require(:user)
    permitted =
      case type_name
      when LegalEntity::PayoutMethod::Check.name
        root.permit(payout_method_attributes: [:address_line1, :address_line2, :address_city,
                                               :address_state, :address_postal_code, :address_country])[:payout_method_attributes]
      when LegalEntity::PayoutMethod::AchTransfer.name
        root.permit(payout_method_attributes: [:account_number, :routing_number])[:payout_method_attributes]
      when LegalEntity::PayoutMethod::Wire.name
        root.permit(payout_method_wire: [:address_line1, :address_line2, :address_city, :address_state,
                                         :address_postal_code, :recipient_country, :recipient_name,
                                         :bic_code, :account_number] +
                                        LegalEntity::PayoutMethod::Wire.recipient_information_accessors)[:payout_method_wire]
      when LegalEntity::PayoutMethod::WiseTransfer.name
        root.permit(payout_method_wise_transfer: [:address_line1, :address_line2, :address_city, :address_state,
                                                  :address_postal_code, :recipient_country, :currency] +
                                                 LegalEntity::PayoutMethod::WiseTransfer.recipient_information_accessors)[:payout_method_wise_transfer]
      end

    permitted || {}
  end

  def payout_locked!
    return false if current_user.can_update_payout_method?

    flash[:error] = "You can't change your payout method while a payout is being processed."
    redirect_back_or_to settings_payouts_path
    true
  end

end
