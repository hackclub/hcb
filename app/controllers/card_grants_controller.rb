# frozen_string_literal: true

class CardGrantsController < ApplicationController
  include SetEvent

  skip_before_action :signed_in_user, only: [:show, :spending]
  skip_after_action :verify_authorized, only: [:show, :spending]

  before_action :set_event, only: %i[new create]
  before_action :set_card_grant, except: %i[new create]

  def new
    @card_grant = @event.card_grants.build

    authorize @card_grant

    @prefill_email = params[:email]

    @event.create_card_grant_setting unless @event.card_grant_setting.present?

    last_card_grant = @event.card_grants.order(created_at: :desc).first

    if last_card_grant.present?
      @card_grant.amount_cents = last_card_grant.amount_cents
      @card_grant.merchant_lock = last_card_grant.merchant_lock
      @card_grant.category_lock = last_card_grant.category_lock
    end

    @card_grant.amount_cents = params[:amount_cents] if params[:amount_cents]
  end

  def create
    params[:card_grant][:amount_cents] = Monetize.parse(params[:card_grant][:amount_cents]).cents
    @card_grant = @event.card_grants.build(params.require(:card_grant).permit(:amount_cents, :email, :merchant_lock, :category_lock, :keyword_lock, :purpose).merge(sent_by: current_user))

    authorize @card_grant

    @card_grant.save!

    flash[:success] = "Successfully sent a grant to #{@card_grant.email}!"

  rescue => e
    flash[:error] = "Something went wrong. #{e.message}"
    Rails.error.report(e)
  ensure
    redirect_to event_transfers_path(@event)
  end

  def update
    authorize @card_grant

    if @card_grant.update(params.require(:card_grant).permit(:purpose))
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

    @event = @card_grant.event
    @card = @card_grant.stripe_card
    @hcb_codes = @card_grant.visible_hcb_codes

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
  end

  def edit
    authorize @card_grant
  end

  private

  def set_card_grant
    @card_grant = CardGrant.find_by_hashid!(params.require(:id))
  end

end
