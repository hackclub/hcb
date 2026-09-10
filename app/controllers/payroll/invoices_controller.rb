# frozen_string_literal: true

module Payroll
  class InvoicesController < ApplicationController
    include SetEvent

    before_action :set_position, only: [:new, :create]
    before_action :set_event, only: [:approve, :reject, :new_on_behalf, :create_on_behalf]
    before_action :set_event_position, only: [:new_on_behalf, :create_on_behalf]
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
        amount_cents: Monetize.parse(invoice_params[:amount], @position.currency).cents
      )
      authorize @invoice

      attachments = Array(invoice_params[:file]).compact_blank
      if attachments.empty?
        flash.now[:error] = "Please attach an invoice or supporting document."
        return render :new, layout: false, status: :unprocessable_content
      end

      ActiveRecord::Base.transaction do
        @invoice.save!
        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments:,
          upload_method: :contractor_invoice,
          receiptable: @invoice
        ).run!
      end

      flash[:success] = "Invoice submitted for review."
      redirect_to my_pay_path
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:error] = e.message
      render :new, layout: false, status: :unprocessable_content
    end

    def approve
      authorize @invoice

      unless @invoice.submitted?
        flash[:error] = "This invoice has already been reviewed."
        return redirect_to contractor_page
      end

      if (error = insufficient_balance_error(@invoice))
        flash[:error] = error
        return redirect_to contractor_page
      end

      pay_invoice!(@invoice)

      flash[:success] = "Invoice approved! #{helpers.possessive(@invoice.payroll_position.payee.display_name)} payment will be sent after HCB review."
      redirect_to contractor_page
    end

    def new_on_behalf
      @invoice = @position.invoices.build
      authorize @invoice, :create_on_behalf?
      render layout: false
    end

    # A manager submits an invoice for a contractor and it is approved in the
    # same step (the manager already holds the review permission), creating the
    # payment straight away.
    def create_on_behalf
      @invoice = @position.invoices.build(
        name: invoice_params[:name],
        description: invoice_params[:description],
        currency: @position.currency,
        amount_cents: Monetize.parse(invoice_params[:amount], @position.currency).cents
      )
      authorize @invoice, :create_on_behalf?

      attachments = Array(invoice_params[:file]).compact_blank
      if attachments.empty?
        flash.now[:error] = "Please attach an invoice or supporting document."
        return render :new_on_behalf, layout: false, status: :unprocessable_content
      end

      if (error = insufficient_balance_error(@invoice))
        flash.now[:error] = error
        return render :new_on_behalf, layout: false, status: :unprocessable_content
      end

      ActiveRecord::Base.transaction do
        @invoice.save!
        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments:,
          upload_method: :contractor_invoice,
          receiptable: @invoice
        ).run!
        pay_invoice!(@invoice)
      end

      flash[:success] = "Invoice submitted and approved. #{helpers.possessive(@position.payee_display_name)} payment will be sent after HCB review."
      redirect_to event_payroll_position_path(event_id: @event.slug, id: @position.id)
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:error] = e.message
      render :new_on_behalf, layout: false, status: :unprocessable_content
    end

    def reject
      authorize @invoice

      if @invoice.submitted?
        @invoice.mark_rejected!(current_user)
        flash[:success] = "Invoice rejected."
      else
        flash[:error] = "This invoice has already been reviewed."
      end

      redirect_to contractor_page
    end

    private

    # The position an invoice is being submitted against. Access (i.e. that the
    # signed-in user belongs to the position's legal entity) is enforced by
    # Payroll::InvoicePolicy when we authorize the built invoice.
    def set_position
      @position = Payroll::Position.find(params[:payroll_position_id])
    end

    # The position a manager is invoicing on behalf of, scoped to this event.
    def set_event_position
      @position = @event.payroll_positions.find(params[:id])
    end

    # Creates the payment for an approved invoice and marks it approved.
    def pay_invoice!(invoice)
      ActiveRecord::Base.transaction do
        payment = Payment.create!(
          payee: invoice.payroll_position.payee,
          creator: current_user,
          amount_cents: invoice.amount_cents,
          currency: invoice.currency,
          purpose: invoice.name
        )
        invoice.update!(payment:)
        invoice.mark_approved!(current_user)
      end
    end

    # An error message if the event can't cover the invoice, otherwise nil.
    def insufficient_balance_error(invoice)
      amount_usd_cents = MoneyService.convert_to_usd(invoice.amount_cents, invoice.currency)
      return nil if amount_usd_cents <= @event.balance_available_v2_cents

      "Your organization doesn't have enough money to pay this invoice. Your balance is #{helpers.render_money(@event.balance_available_v2_cents)}."
    end

    # Invoices belonging to one of this event's contractors (review side).
    def set_invoice
      @invoice = @event.payroll_invoices.find(params[:id])
    end

    def contractor_page
      event_payroll_position_path(event_id: @event.slug, id: @invoice.payroll_position)
    end

    def invoice_params
      params.require(:payroll_invoice).permit(:name, :amount, :description, file: [])
    end

  end
end
