# frozen_string_literal: true

module Payroll
  # Handles both sides of a Payroll::Invoice's lifecycle:
  #   * the contractor submitting an invoice against their own position
  #     (new/create, nested under /my/payroll_positions), and
  #   * an organizer approving or rejecting a submitted invoice
  #     (approve/reject, nested under the event's contractors area).
  class InvoicesController < ApplicationController
    include SetEvent

    before_action :set_position, only: [:new, :create]
    before_action :set_event, only: [:approve, :reject]
    before_action :set_invoice, only: [:approve, :reject]

    def new
      @invoice = @position.invoices.build
      authorize @invoice
      render layout: false
    end

    def create
      @invoice = @position.invoices.build(
        name: invoice_params[:name],
        description: invoice_params[:description],
        currency: @position.currency,
        amount: invoice_params[:amount]
      )
      authorize @invoice

      attachments = Array(invoice_params[:file]).compact_blank
      if attachments.empty?
        flash.now[:error] = "Please attach an invoice or supporting document."
        return render :new, layout: false, status: :unprocessable_entity
      end

      ActiveRecord::Base.transaction do
        @invoice.save!
        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments:,
          upload_method: :transfer_create_page,
          receiptable: @invoice
        ).run!
      end

      Payroll::InvoiceMailer.with(invoice: @invoice).submitted.deliver_later
      flash[:success] = "Invoice submitted for review."
      redirect_to my_pay_path
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:error] = e.message
      render :new, layout: false, status: :unprocessable_entity
    end

    def approve
      authorize @invoice

      unless @invoice.submitted?
        flash[:error] = "This invoice has already been reviewed."
        return redirect_to contractor_page
      end

      if @invoice.amount_cents > @event.balance_available_v2_cents
        flash[:error] = "Your organization doesn't have enough money to pay this invoice. Your balance is #{helpers.render_money(@event.balance_available_v2_cents)}."
        return redirect_to contractor_page
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
      redirect_to contractor_page
    end

    def reject
      authorize @invoice

      if @invoice.submitted?
        @invoice.mark_rejected!
        flash[:success] = "Invoice rejected."
      else
        flash[:error] = "This invoice has already been reviewed."
      end

      redirect_to contractor_page
    end

    private

    # Positions belonging to the signed-in contractor (submit side).
    def set_position
      @position = Payroll::Position.joins(:payee)
                                   .where(payees: { email: current_user.email })
                                   .find(params[:payroll_position_id])
    end

    # Invoices belonging to one of this event's contractors (review side).
    def set_invoice
      @invoice = Payroll::Invoice.joins(payroll_position: :payee)
                                 .where(payees: { event_id: @event.id })
                                 .find(params[:id])
    end

    def contractor_page
      event_contractor_path(event_id: @event.slug, id: @invoice.payroll_position_id)
    end

    def invoice_params
      params.require(:payroll_invoice).permit(:name, :amount, :description, file: [])
    end

  end
end
