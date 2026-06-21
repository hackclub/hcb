# frozen_string_literal: true

class Donation
  class AlertsController < ApplicationController
    include SetEvent

    before_action :set_event
    before_action :set_alert, only: [:edit, :destroy, :toggle_subscription]

    def index
      authorize @event, :update?
      @alerts = @event.donation_alerts.order(created_at: :desc)
    end

    def new
      @alert = @event.donation_alerts.build
      authorize @alert, :create?
    end

    def create
      @alert = @event.donation_alerts.new(
        alert_name: "Untitled alert",
        amount_cents: 10_00,
        alert_message: "",
        active: false
      )

      authorize @alert, :create?
      @alert.save!

      render partial: "events/settings/donation_alerts", locals: { event: @event, frame: false }
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = e.message
      render partial: "events/settings/donation_alerts", locals: { event: @event, frame: false }, status: :unprocessable_entity
    end

    def edit
      authorize @alert, :update?
    end

    def update
      alerts = []
      params[:alerts]&.each_key do |id|
        alert = @event.donation_alerts.find_by(id: id)
        next unless alert

        authorize alert, :update?
        alerts << alert
      end

      alerts.each do |alert|
        data = alert_params(alert.id)

        alert.update!(
          alert_name: data[:alert_name],
          alert_message: data[:alert_message],
          amount_cents: (data[:amount_cents].to_f * 100).to_i,
          active: ActiveRecord::Type::Boolean.new.cast(data[:active])
        )
      end

      render partial: "events/settings/donation_alerts", locals: { event: @event, frame: false }
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = e.message
      render partial: "events/settings/donation_alerts", locals: { event: @event, frame: false }, status: :unprocessable_entity
    end

    def destroy
      @alert = @event.donation_alerts.find(params[:id])
      authorize @alert, :destroy?

      @alert.destroy
      redirect_to edit_event_path(@event.slug, tab: "donations"),
                  flash: { success: "Donation tiers updated successfully." }
    rescue ActiveRecord::RecordInvalid => e
      redirect_to edit_event_path(@event.slug, tab: "donations"),
                  flash: { error: e.message }
    end

    def toggle_subscription
      authorize @alert, :show?

      if @alert.subscribed?(current_user)
        @alert.unsubscribe(current_user)
        message = "You've unsubscribed from this alert."
      else
        @alert.subscribe(current_user)
        message = "You've subscribed to this alert!"
      end

      redirect_back fallback_location: edit_event_path(@event.slug, tab: "donations"), notice: message
    end

    def subscribe_to_all
      unless @event.users.include?(current_user)
        redirect_to root_path, alert: "You must be an organization member to subscribe."
        return
      end

      alerts = @event.donation_alerts.active
      already_subscribed = alerts.all? { |a| a.subscribed?(current_user) }

      alerts.each do |alert|
        if already_subscribed
          alert.unsubscribe(current_user)
        else
          alert.subscribe(current_user)
        end
      end

      message = already_subscribed ? "Unsubscribed from all alerts." : "Subscribed to all alerts."
      redirect_back fallback_location: edit_event_path(@event.slug, tab: "donations"), notice: message
    end

    private

    def set_alert
      @alert = @event.donation_alerts.find(params[:id])
    end

    def alert_params(id)
      params
        .require(:alerts)
        .require(id.to_s)
        .permit(:alert_name, :amount_cents, :alert_message, :active)
    end

  end

end
