# frozen_string_literal: true

module Events
  class PaymentsController < ApplicationController
    include SetEvent

    before_action :set_event

    def new
      authorize @event, :new_payment?
      @payment = Payment.new
      @payee = @event.payees.find(params[:payee_id]) if params[:payee_id].present?
      render layout: "transfer"
    end

    def create
      authorize @event, :create_payment?

      @payee = @event.payees.find(payment_params[:payee_id])
      @payment = Payment.new(payment_params.except(:payee_id).merge(creator: current_user, payee: @payee, currency: "USD"))

      if @payment.save
        redirect_to event_payments_path(event_id: @event.slug), notice: "Payment submitted for review."
      else
        render :new, layout: "transfer", status: :unprocessable_entity
      end
    end

    private

    def payment_params
      params.require(:payment).permit(:amount, :purpose, :payee_id)
    end

  end
end
