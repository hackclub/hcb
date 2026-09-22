# frozen_string_literal: true

module Payroll
  class InvoicesController < ApplicationController
    include SetEvent

    before_action :set_position, only: [:new, :create]
    before_action :set_event, only: [:approve, :reject]
    before_action :set_invoice, only: [:approve, :reject]

    def new
      @invoice = @position.invoices.build
      authorize @invoice
      @on_behalf = policy(@invoice).on_behalf?
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
      @on_behalf = policy(@invoice).on_behalf?

      attachments = Array(invoice_params[:file]).compact_blank
      if attachments.empty?
        flash.now[:error] = "Please attach an invoice or supporting document."
        return render_form_error
      end

      ActiveRecord::Base.transaction do
        @invoice.save!
        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments:,
          upload_method: :contractor_invoice,
          receiptable: @invoice
        ).run!

        if @on_behalf && !@invoice.approve(reviewed_by: current_user)
          @invoice.errors.add(:base, insufficient_balance_message(@position.event))
          raise ActiveRecord::RecordInvalid, @invoice
        end
      end

      if @on_behalf
        flash[:success] = "Invoice approved for #{@position.payee.display_name}! Payment will be sent after HCB review."
        redirect_to contractor_page
      else
        flash[:success] = "Invoice submitted for review."
        redirect_to my_pay_path
      end
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:error] = e.record.errors.full_messages.to_sentence
      render_form_error
    end

    def approve
      authorize @invoice

      if @invoice.approve(reviewed_by: current_user)
        flash[:success] = "Invoice approved! #{helpers.possessive(@invoice.payroll_position.payee.display_name)} payment will be sent after HCB review."
      elsif !@invoice.submitted?
        flash[:error] = "This invoice has already been reviewed."
      else
        flash[:error] = insufficient_balance_message(@event)
      end

      redirect_to contractor_page
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

    # Invoices belonging to one of this event's contractors (review side).
    def set_invoice
      @invoice = @event.payroll_invoices.find(params[:id])
    end

    # The form targets _top so success can redirect; errors re-render only the form, inside its modal.
    def render_form_error
      render turbo_stream: turbo_stream.replace([@position, :invoice_form], template: "payroll/invoices/new"), status: :unprocessable_content
    end

    def insufficient_balance_message(event)
      "Your organization doesn't have enough money to pay this invoice. Your balance is #{helpers.render_money(event.balance_available_v2_cents)}."
    end

    def contractor_page
      event_payroll_position_path(event_id: @invoice.event.slug, id: @invoice.payroll_position)
    end

    def invoice_params
      params.require(:payroll_invoice).permit(:name, :amount, :description, file: [])
    end

  end
end
