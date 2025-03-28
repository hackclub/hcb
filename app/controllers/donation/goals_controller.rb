# frozen_string_literal: true

class Donation
  class GoalsController < ApplicationController
    include SetEvent
    before_action :set_event

    def create
      authorize @event, :update?

      if @event.donation_goal.present?
        redirect_back fallback_location: edit_event_path(@event.slug), flash: { error: "Please delete your existing goal first" }
      else
        amount_cents = Money.from_amount(goal_params[:amount_cents].to_f).cents
        @goal = @event.build_donation_goal(amount_cents: amount_cents)
        @goal.save!

        redirect_back fallback_location: edit_event_path(@event.slug), flash: { success: "Donation goal created successfully." }
      end
    end

    def update
      authorize @event, :update?

      if params[:donation_goal_enabled] == "0"
        @event.donation_goal.destroy
        return redirect_back fallback_location: edit_event_path(@event.slug), flash: { success: "Donation goal removed successfully." }
      end

      amount_cents = Money.from_amount(params[:amount_cents].to_f).cents

      @event.donation_goal.update!(amount_cents: amount_cents)
      if params[:reset_donation_goal] == "on"
        @event.donation_goal.update!(tracking_since: Time.current)
      end

      redirect_back fallback_location: edit_event_path(@event.slug), flash: { success: "Donation goal updated successfully." }
    rescue ActiveRecord::RecordInvalid => e
      redirect_back fallback_location: edit_event_path(@event.slug), flash: { error: e.message }
    end

    private

    def goal_params
      params.permit(:amount_cents)
    end

  end

end
