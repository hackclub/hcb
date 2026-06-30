# frozen_string_literal: true


class PayoutMethodsController < ApplicationController
  before_action :authorize_payout_edit
  before_action :set_payout_method, only: [:update, :set_default, :destroy]
  before_action :require_unlocked_method, only: [:update, :destroy]

  def create
    service = LegalEntity::PayoutMethodService::Update.new(
      user: current_user,
      details_type: params.dig(:user, :payout_method_type),
      details_attrs: details_params_for(params.dig(:user, :payout_method_type)),
      make_default: legal_entity.payout_methods.unarchived.none?
    )

    if service.run
      flash[:success] = "Payout method added."
      redirect_back_or_to settings_payouts_path
    else
      render_payout_settings(service.payout_method)
    end
  end

  def update
    service = LegalEntity::PayoutMethodService::Update.new(
      user: current_user,
      details_type: @payout_method.details_type,
      details_attrs: details_params_for(@payout_method.details_type),
      make_default: @payout_method.default?,
      replacing: @payout_method
    )

    if service.run
      flash[:success] = "Payout method updated."
      redirect_back_or_to settings_payouts_path
    else
      render_payout_settings(service.payout_method)
    end
  end

  def set_default
    @payout_method.update!(default: true)
    flash[:success] = "Default payout method updated."
    redirect_back_or_to settings_payouts_path
  end

  def destroy
    # The default can't be removed directly — the user must promote another
    # method to default first (which leaves this one removable).
    if @payout_method.default?
      flash[:error] = "Set another payout method as default before removing this one."
      return redirect_back_or_to settings_payouts_path
    end

    # Capture the draft reports pinned to this method before archiving so we can
    # fall them back to the default (a non-default method is being removed, so a
    # default still exists).
    draft_report_ids = @payout_method.reimbursement_reports.where(aasm_state: :draft).pluck(:id)

    @payout_method.archive!

    default = legal_entity.default_payout_method
    if default && draft_report_ids.any?
      Reimbursement::Report.where(id: draft_report_ids).find_each do |report|
        report.update!(legal_entity_payout_method: default)
      end
    end

    flash[:success] = "Payout method removed."
    redirect_back_or_to settings_payouts_path
  end

  private

  def authorize_payout_edit
    authorize current_user, :edit_payout?
  end

  # Per-method, report-aware lock: editing or removing a method is blocked only
  # while a report using it is in-flight (submitted → approved). Adding a new
  # method or pointing the default at a different record is always allowed and
  # never reaches this filter.
  def require_unlocked_method
    return unless @payout_method&.locked_by_processing_report?

    flash[:error] = "You can't change this payout method while a reimbursement is being processed."
    redirect_back_or_to settings_payouts_path
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
    @payout_method = legal_entity&.payout_methods&.unarchived&.find_by(id: params[:id])
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

end
