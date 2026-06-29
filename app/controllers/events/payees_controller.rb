# frozen_string_literal: true

module Events
  class PayeesController < ApplicationController
    include SetEvent

    before_action :set_event

    def index
      authorize @event.payees.build, :index?
      @payees = params[:q].present? ? @event.payees.search(params[:q]) : @event.payees
      render layout: false
    end

    def create
      payee = @event.payees.build(display_name: params[:name], email: params[:email])
      authorize payee

      if payee.save
        redirect_to event_payments_new_path(event_id: @event.slug, payee_id: payee.id)
      else
        redirect_to event_payments_new_path(event_id: @event.slug),
                    alert: payee.errors.full_messages.to_sentence
      end
    end

  end
end
