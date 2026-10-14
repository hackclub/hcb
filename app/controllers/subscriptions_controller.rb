# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  include SetEvent

  before_action :set_event
  before_action :set_subscription, except: :index

  def index
    authorize @event, :subscriptions?

    subscriptions = @event.subscriptions
                          .includes(stripe_card: { stripe_cardholder: :user })
                          .order(Arel.sql("subscriptions.last_charged_at DESC NULLS LAST"), created_at: :desc)

    @active_subscriptions = subscriptions.active.to_a
    @canceled_subscriptions = subscriptions.canceled.to_a
    @stats = {
      monthly_cents: @active_subscriptions.sum { |subscription| subscription.monthly_cents.to_i },
      yearly_cents: @active_subscriptions.sum { |subscription| subscription.yearly_cents.to_i },
    }
  end

  def show
    authorize @subscription

    @hcb_codes = @subscription.hcb_codes.order(created_at: :desc)
  end

  def update
    authorize @subscription

    if @subscription.update(subscription_params)
      @subscription.sync_charges!
      flash[:success] = "Subscription updated."
    else
      flash[:error] = @subscription.errors.full_messages.to_sentence
    end

    redirect_to event_subscription_path(@event, @subscription)
  end

  def cancel
    authorize @subscription

    @subscription.cancel!

    redirect_to event_subscription_path(@event, @subscription), flash: { success: "Subscription marked as canceled." }
  end

  def destroy
    authorize @subscription

    @subscription.destroy!

    redirect_to event_subscriptions_path(@event), flash: { success: "Removed #{@subscription.name}. Its charges need receipts again." }
  end

  private

  def set_subscription
    @subscription = @event.subscriptions.find(params[:id])
  end

  def subscription_params
    params.require(:subscription).permit(:name, :amount, :cadence, :cadence_days)
  end

end
