# frozen_string_literal: true

class StripeCardsController < ApplicationController
  include SetEvent
  before_action :set_event, only: [:new]

  def index
    @cards = StripeCard.all
    authorize @cards
  end

  def shipping
    # Only show shipping for phyiscal cards if the eta is in the future (or 1 week after)
    @stripe_cards = current_user.stripe_cards.where.not(stripe_status: "canceled").physical_shipping.filter do |sc|
      sc.shipping_eta&.after?(1.week.ago)
    end
    skip_authorization # do not force pundit

    render :shipping, layout: false
  end

  def freeze
    @card = StripeCard.find(params[:id])
    authorize @card

    if @card.freeze!
      flash[:success] = "Card frozen"
      redirect_back_or_to @card
    else
      render :show, status: :unprocessable_entity
    end
  end

  def cancel
    @card = StripeCard.find(params[:id])
    authorize @card

    @card.cancel!
    flash[:success] = "Card cancelled"
    redirect_back_or_to @card
  rescue => e
    flash[:error] = e.message
    render :show, status: :unprocessable_entity
  end

  def defrost
    @card = StripeCard.find(params[:id])
    authorize @card

    if @card.defrost!
      flash[:success] = "Card defrosted"
      redirect_back_or_to @card
    else
      render :show, status: :unprocessable_entity
    end
  end

  def show
    @card = StripeCard.includes(:event, :user).find(params[:id])

    if @card.card_grant.present? && !current_user&.auditor?
      authorize @card.card_grant
      return redirect_to card_grant_path(@card.card_grant, frame: params[:frame])
    end

    authorize @card

    if params[:show_details] == "true"
      ahoy.track "Card details shown", stripe_card_id: @card.id
    end

    @show_card_details = params[:show_details] == "true"
    @event = @card.event

    @hcb_codes = @card.hcb_codes
                      .includes(canonical_pending_transactions: [:raw_pending_stripe_transaction], canonical_transactions: :transaction_source)
                      .page(params[:page]).per(25)

    if params[:frame] == "true"
      @frame = true
      @force_no_popover = true
      render :show, layout: false
    else
      @frame = false
      render :show
    end
  end

  def new
    authorize @event, :new_stripe_card?, policy_class: EventPolicy
  end

  def create
    event = Event.find(params[:stripe_card][:event_id])
    authorize event, :create_stripe_card?, policy_class: EventPolicy

    sc = stripe_card_params

    if current_user.birthday.nil?
      user_params = sc.slice("birthday(1i)", "birthday(2i)", "birthday(3i)")
      current_user.update(user_params)
    end

    return redirect_back fallback_location: event_cards_new_path(event), flash: { error: "Birthday is required" } if current_user.birthday.nil?
    return redirect_back fallback_location: event_cards_new_path(event), flash: { error: "Invalid country" } unless sc[:stripe_shipping_address_country] == "US"

    new_card = ::StripeCardService::Create.new(
      current_user:,
      current_session:,
      event_id: event.id,
      card_type: sc[:card_type],
      stripe_shipping_name: sc[:stripe_shipping_name],
      stripe_shipping_address_city: sc[:stripe_shipping_address_city],
      stripe_shipping_address_state: sc[:stripe_shipping_address_state],
      stripe_shipping_address_line1: sc[:stripe_shipping_address_line1],
      stripe_shipping_address_line2: sc[:stripe_shipping_address_line2],
      stripe_shipping_address_postal_code: sc[:stripe_shipping_address_postal_code],
      stripe_shipping_address_country: sc[:stripe_shipping_address_country],
      stripe_card_personalization_design_id: sc[:stripe_card_personalization_design_id] || StripeCard::PersonalizationDesign.common.first&.id
    ).run

    redirect_to new_card, flash: { success: "Card was successfully created." }
  rescue => e
    Rails.error.report(e)

    redirect_to event_cards_new_path(event), flash: { error: e.message }
  end

  def edit
    @card = StripeCard.find(params[:id])
    @event = @card.event
    authorize @card
  end

  def update
    card = StripeCard.find(params[:id])
    authorize card
    if card.update(params.require(:stripe_card).permit(:name))
      flash[:success] = "Card's name has been successfully updated!"
    else
      flash[:error] = card.errors.full_messages.to_sentence || "Card's name could not be updated"
    end

    redirect_to stripe_card_url(card)
  end

  def enable_cash_withdrawal
    card = StripeCard.find(params[:id])
    authorize card
    card.toggle!(:cash_withdrawal_enabled)
    if card.cash_withdrawal_enabled?
      confetti!(emojis: %w[💵 💴 💶 💷])
      flash[:success] = "You've enabled cash withdrawals for this card."
    else
      flash[:success] = "You've disabled cash withdrawals for this card."
    end
    redirect_to stripe_card_url(card)
  end

  def ephemeral_keys
    card = StripeCard.find(params[:id])

    authorize card

    ephemeral_key = card.ephemeral_key(nonce: params[:nonce])

    ahoy.track "Card details shown", stripe_card_id: card.id

    render json: { ephemeralKeySecret: ephemeral_key.secret, stripe_id: card.stripe_id }
  end

  private

  def suggested(field)
    return nil unless current_user

    ecr = EmburseCardRequest.where(creator_id: current_user&.id)
    case field
    when :phone_number
      current_user.phone_number
    when :name
      current_user.full_name
    when :line1
      current_user&.stripe_cardholder&.stripe_billing_address_line1 ||
        ecr&.last&.shipping_address_street_one
    when :line2
      current_user&.stripe_cardholder&.stripe_billing_address_line2 ||
        ecr&.last&.shipping_address_street_two
    when :city
      current_user&.stripe_cardholder&.stripe_billing_address_city ||
        ecr&.last&.shipping_address_city
    when :state
      current_user&.stripe_cardholder&.stripe_billing_address_state ||
        ecr&.last&.shipping_address_state
    when :postal_code
      current_user&.stripe_cardholder&.stripe_billing_address_postal_code ||
        ecr&.last&.shipping_address_zip
    when :country
      current_user&.stripe_cardholder&.stripe_billing_address_country ||
        ("US" if ecr.any?)
    else
      nil
    end
  end

  # Only allow a trusted parameter "white list" through.
  def stripe_card_params
    params.require(:stripe_card).permit(
      :event_id,
      :card_type,
      :stripe_cardholder_id,
      :stripe_shipping_name,
      :stripe_shipping_address_city,
      :stripe_shipping_address_line1,
      :stripe_shipping_address_postal_code,
      :stripe_shipping_address_line2,
      :stripe_shipping_address_state,
      :stripe_shipping_address_country,
      :stripe_card_personalization_design_id,
      :birthday
    )
  end

end
