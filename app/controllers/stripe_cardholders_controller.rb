# frozen_string_literal: true

class StripeCardholdersController < ApplicationController
  include SetEvent
  before_action :set_event, only: [:new]

  def new
    @stripe_cardholder = StripeCardholder.new

    authorize @stripe_cardholder
  end

  def create
    @event = Event.find params[:stripe_cardholder][:event_id]
    @stripe_cardholder = StripeCardholder.new(stripe_cardholder_params)

    authorize @stripe_cardholder
    if @stripe_cardholder.save
      redirect_to event_stripe_cards_new_path(event_id: @event.slug, stripe_cardholder_id: @stripe_cardholder.id)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @stripe_cardholder = current_user.stripe_cardholder

    authorize @stripe_cardholder
    if @stripe_cardholder.save
      redirect_to
    else
      render
    end
  end

  def update_profile
    @stripe_cardholder = StripeCardholder.find_or_initialize_by(user: current_user)

    authorize @stripe_cardholder
    if @stripe_cardholder.update(stripe_cardholder_params)
      redirect_back(fallback_location: root_path)
    else
      render "users/edit", status: :unprocessable_entity
    end
  end

  private

  # Only allow a trusted parameter "white list" through.
  def stripe_cardholder_params
    params.require(:stripe_cardholder).permit(
      :user_id,
      :stripe_billing_address_line1,
      :stripe_billing_address_line2,
      :stripe_billing_address_city,
      :stripe_billing_address_state,
      :stripe_billing_address_postal_code,
      :stripe_billing_address_country
    )
  end

end
