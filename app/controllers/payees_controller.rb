# frozen_string_literal: true

class PayeesController < ApplicationController
  include SetEvent

  before_action :set_event

  def index
    authorize @event
    @payees = params[:q].present? ? @event.payees.search(params[:q]) : @event.payees
    render layout: false
  end

  def create
    payee = @event.payees.build(display_name: params[:name], email: params[:email])
    authorize payee

    if payee.save
      redirect_to new_event_payment_path(event_id: @event.slug, payee_id: payee.id)
    else
      redirect_to new_event_payment_path(event_id: @event.slug),
                  alert: payee.errors.full_messages.to_sentence
    end
  end

end
