# frozen_string_literal: true

class ContractorInvoicesController < ApplicationController
  include SetEvent

  before_action :set_event
  before_action :set_invoice

  def approve
    authorize @event, :review?, policy_class: ContractorPolicy

    unless @invoice.submitted?
      flash[:error] = "This invoice has already been reviewed."
      return redirect_to event_contractor_path(event_id: @event.slug, id: @invoice.payroll_position_id)
    end

    if @invoice.amount_cents > @event.balance_available_v2_cents
      flash[:error] = "Your organization doesn't have enough money to pay this invoice. Your balance is #{helpers.render_money(@event.balance_available_v2_cents)}."
      return redirect_to event_contractor_path(event_id: @event.slug, id: @invoice.payroll_position_id)
    end

    ActiveRecord::Base.transaction do
      payment = Payment.create!(
        payee: @invoice.payroll_position.payee,
        creator: current_user,
        amount_cents: @invoice.amount_cents,
        currency: @invoice.currency,
        purpose: @invoice.name
      )
      @invoice.update!(payment:)
      @invoice.mark_approved!(current_user)
    end

    flash[:success] = "Invoice approved. Payment initiated."
    redirect_to event_contractor_path(event_id: @event.slug, id: @invoice.payroll_position_id)
  end

  def reject
    authorize @event, :review?, policy_class: ContractorPolicy

    if @invoice.submitted?
      @invoice.mark_rejected!
      flash[:success] = "Invoice rejected."
    else
      flash[:error] = "This invoice has already been reviewed."
    end

    redirect_to event_contractor_path(event_id: @event.slug, id: @invoice.payroll_position_id)
  end

  private

  # Scope to invoices belonging to this event's contractors.
  def set_invoice
    @invoice = Payroll::Invoice.joins(payroll_position: :payee)
                               .where(payees: { event_id: @event.id })
                               .find(params[:id])
  end

end
