# frozen_string_literal: true

class Events::PayeesController < ApplicationController
  include SetEvent

  before_action :set_event

  def index
    authorize @event, :new_payment?
    @payees = @event.payees.search(params[:q])
    render layout: false
  end

  def create
    authorize @event, :new_payment?

    payee = @event.payees.new(display_name: params[:name], email: params[:email])

    if payee.save
      redirect_to event_payments_new_path(event_id: @event.slug, payee_id: payee.id)
    else
      redirect_to event_payments_new_path(event_id: @event.slug),
                  alert: payee.errors.full_messages.to_sentence
    end
  end
end
