# frozen_string_literal: true

class CardGrantsController < ApplicationController
  include SetEvent

  skip_before_action :signed_in_user, only: [:show, :spending]
  skip_after_action :verify_authorized, only: [:show, :spending]

  before_action :set_event, only: %i[new create]
  before_action :set_card_grant, except: %i[new create]

  def new
    @card_grant = @event.card_grants.build(email: params[:email])

    authorize @card_grant

    @event.create_card_grant_setting! unless @event.card_grant_setting.present?

    @card_grant.amount_cents = params[:amount_cents] if params[:amount_cents]
  end

  def create
    params[:card_grant][:amount_cents] = Monetize.parse(params[:card_grant][:amount_cents]).cents
    cg_params = params.require(:card_grant).permit(:amount_cents, :email, :keyword_lock, :purpose, :one_time_use, :pre_authorization_required, :instructions).merge(sent_by: current_user)
    @card_grant = @event.card_grants.build(cg_params)

    authorize @card_grant

    begin
      # There's no way to save a card grant without potentially triggering an
      # exception as under the hood it calls `DisbursementService::Create` and a
      # number of other methods (e.g. `save!`) which either succeed or raise.
      @card_grant.save!

      default_cg_setting = @event.card_grant_setting
      CardGrantSetting.create!(
        {
          banned_categories: default_cg_setting.banned_categories,
          banned_merchants: default_cg_setting.banned_merchants,
          category_lock: default_cg_setting.category_lock,
          expiration_preference: default_cg_setting.expiration_preference,
          invite_message: default_cg_setting.invite_message,
          keyword_lock: cg_params.card_grant.keyword_lock,
          merchant_lock: default_cg_setting.merchant_lock,
          pre_authorization_required: cg_params.card_grant.pre_authorization_required,
          reimbursement_conversions_enabled: default_cg_setting.reimbursement_conversions_enabled,
          card_grant_id: @card_grant.id,
          event_id: @event.id
        }
      )
    rescue => e
      case e
      when ActiveRecord::RecordInvalid
        # We expect to encounter validation errors from `CardGrant`, but anything
        # else is the result of downstream logic which shouldn't fail.
        raise e unless e.record.is_a?(CardGrant)

        flash[:error] = @card_grant.errors.full_messages.to_sentence
      when DisbursementService::Create::UserError
        flash[:error] = e.message
      else
        raise e
      end

      render(:new, status: :unprocessable_entity)
      return
    end

    flash[:success] = "Successfully sent a grant to #{@card_grant.email}!"
    redirect_to event_transfers_path(@event)
  end

  def edit_overview
    authorize @card_grant
  end

  def edit_purpose
    authorize @card_grant
  end

  def edit_actions
    authorize @card_grant
  end

  def edit_balance
    authorize @card_grant
  end

  def edit_usage_restrictions
    authorize @card_grant
  end

  def edit_topup
    authorize @card_grant
  end

  def edit_withdraw
    authorize @card_grant
  end

  def update
    authorize @card_grant

    if @card_grant.setting
      @card_grant.setting.update(params.require(:card_grant).permit(:merchant_lock, :category_lock, :keyword_lock))
    end

    if @card_grant.update(params.require(:card_grant).permit(:purpose, :merchant_lock, :category_lock, :keyword_lock))
      flash[:success] = "Grant's purpose has been successfully updated!"
    else
      flash[:error] = @card_grant.errors.full_messages.to_sentence
    end

    redirect_to card_grant_url(@card_grant)
  end

  def clear_purpose
    authorize @card_grant, :update?
    @card_grant.update(purpose: nil)
    redirect_back fallback_location: card_grant_url(@card_grant)
  end

  def show
    if !signed_in?
      url_queries = { return_to: card_grant_path(@card_grant) }
      url_queries[:email] = params[:email] if params[:email]
      return redirect_to auth_users_path(url_queries), flash: { info: "To continue, please sign in with the email you received the grant." }
    end

    authorize @card_grant

    if @card_grant.pre_authorization&.unauthorized? && !organizer_signed_in?
      return redirect_to card_grant_pre_authorizations_path(@card_grant)
    end

    @event = @card_grant.event
    @card = @card_grant.stripe_card
    @hcb_codes = @card_grant.visible_hcb_codes

    @show_card_details = params[:show_details] == "true"

    @frame = params[:frame].present?
    @force_no_popover = @frame

    render :show, layout: !@frame

  rescue Pundit::NotAuthorizedError
    redirect_to auth_users_path(return_to: card_grant_path(@card_grant), error: "unauthorised_card_grant")
  end

  def spending
    authorize @card_grant

    @event = @card_grant.event
    @card = @card_grant.stripe_card
    @hcb_codes = @card&.hcb_codes

    @frame = params[:frame].present?
    @force_no_popover = @frame

    if organizer_signed_in? && !@frame
      # If trying to view spending page outside a frame, redirect to the show page
      return redirect_to @card_grant
    end

    render :spending, layout: !@frame
  end

  def activate
    authorize @card_grant

    @card_grant.create_stripe_card(current_session)

    redirect_to @card_grant
  rescue Stripe::InvalidRequestError => e
    redirect_to @card_grant, flash: { error: "This card could not be activated: #{e.message}" }
  rescue ArgumentError => e
    redirect_to @card_grant, flash: { error: e.message }
  end

  def cancel
    authorize @card_grant

    disbursement = @card_grant.cancel!(current_user)

    redirect_back_or_to event_transfers_path(@card_grant.event), flash: { success: "Successfully canceled grant." }
  end

  def topup
    authorize @card_grant

    @card_grant.topup!(amount_cents: Monetize.parse(params[:amount]).cents, topped_up_by: current_user)

    redirect_to @card_grant, flash: { success: "Successfully topped up grant." }
  rescue DisbursementService::Create::UserError => e
    redirect_to @card_grant, flash: { error: e.message }
  end

  def withdraw
    authorize @card_grant

    @card_grant.withdraw!(amount_cents: Monetize.parse(params[:amount]).cents, withdrawn_by: current_user)

    redirect_to @card_grant, flash: { success: "Successfully withdrew from grant." }

  rescue => e
    Rails.error.report(e) unless e.is_a?(ArgumentError)

    redirect_to @card_grant, flash: { error: e.message }
  end

  def convert_to_reimbursement_report
    authorize @card_grant

    report = @card_grant.convert_to_reimbursement_report!

    redirect_to report, flash: { success: "Successfully converted grant into a reimbursement report." }
  end

  def toggle_one_time_use
    authorize @card_grant

    @card_grant.update(one_time_use: !@card_grant.one_time_use)

    redirect_to @card_grant, flash: { success: "#{@card_grant.one_time_use ? "Enabled" : "Disabled"} one time use for this card grant." }
  end

  def edit
    authorize @card_grant
  end

  private

  def set_card_grant
    @card_grant = CardGrant.find_by_hashid!(params.require(:id))
    @event = @card_grant.event
  end

end
