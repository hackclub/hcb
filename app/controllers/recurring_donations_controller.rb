# frozen_string_literal: true

class RecurringDonationsController < ApplicationController
  include SetEvent

  before_action :set_event, only: [:create, :pay, :finished]
  before_action :set_recurring_donation_by_hashid, only: [:pay, :finished]
  before_action :set_recurring_donation_by_url_hash, only: [:show, :edit, :update, :cancel]

  skip_before_action :signed_in_user
  skip_before_action :redirect_to_onboarding

  invisible_captcha only: [:create], honeypot: :subtitle

  def create
    params[:recurring_donation][:amount] = Monetize.parse(params[:recurring_donation][:amount]).cents

    if params[:recurring_donation][:fee_covered] == "1" && @event.config.cover_donation_fees
      params[:recurring_donation][:amount] = (params[:recurring_donation][:amount] / (1 - @event.revenue_fee)).ceil
    end

    tax_deductible = params[:recurring_donation][:goods].nil? || params[:recurring_donation][:goods] == "0"

    @recurring_donation = RecurringDonation.new(
      params.require(:recurring_donation).permit(:name, :email, :amount, :message, :anonymous, :fee_covered).merge(event: @event, tax_deductible:)
    )

    authorize @recurring_donation

    if @recurring_donation.save
      redirect_to pay_event_recurring_donation_path(@event, @recurring_donation)
    else
      @monthly = true
      render "donations/start_donation", status: :unprocessable_entity
    end
  end

  def pay
    return redirect_to start_donation_donations_path(@event) unless @recurring_donation&.incomplete?
  end

  def finished; end

  def show
    # Handle the Stripe redirect after the user changes their payment method.
    if params[:setup_intent] && params[:redirect_status] == "succeeded"
      setup_intent = StripeService::SetupIntent.retrieve(id: params[:setup_intent], expand: ["payment_method"])
      if setup_intent
        # This is just a UI change— the actual update is handled asynchronously in `StripeController#handle_setup_intent_succeeded`
        @recurring_donation.update(last4: setup_intent.payment_method.card.last4)
        redirect_to recurring_donation_path(@recurring_donation.url_hash), flash: { success: "Your payment details have been updated." }
      end
    end

    @event = @recurring_donation.event

    @placeholder_amount = "%.2f" % (DonationService::SuggestedAmount.new(@event, monthly: true).run / 100.0)
  end

  def edit
    setup_intent = StripeService::SetupIntent.create(
      customer: @recurring_donation.stripe_customer_id,
      usage: "off_session",
      metadata: { recurring_donation_id: @recurring_donation.id, event_id: @recurring_donation.event.id }
    )

    @client_secret = setup_intent.client_secret
  end

  def update
    params[:recurring_donation][:amount] = Monetize.parse(params[:recurring_donation][:amount]).cents if params.dig(:recurring_donation, :amount).present?

    @recurring_donation.update(params.require(:recurring_donation).permit(:amount))

    redirect_back_or_to recurring_donation_path(@recurring_donation.url_hash), flash: { success: "Your donation has been updated." }
  end

  def cancel
    @recurring_donation.cancel!

    redirect_back_or_to recurring_donation_path(@recurring_donation.url_hash), flash: { success: "Your donation has been canceled." }
  end

  private

  def set_recurring_donation_by_hashid
    @recurring_donation = @event.recurring_donations.find_by_hashid!(params[:id])

    authorize @recurring_donation
  end

  def set_recurring_donation_by_url_hash
    @recurring_donation = RecurringDonation.find_by!(url_hash: params[:id])

    authorize @recurring_donation
  end

end
