# frozen_string_literal: true

module Payroll
  class InvoicesController < ApplicationController
    before_action :set_position

    def new
      @invoice = @position.invoices.build
      authorize @invoice
      render layout: false
    end

    def create
      @invoice = @position.invoices.build(
        name: invoice_params[:name],
        description: invoice_params[:description],
        amount_cents: (invoice_params[:amount].to_d * 100).round,
        currency: @position.currency
      )
      authorize @invoice

      attachments = Array(invoice_params[:file]).compact_blank
      if attachments.empty?
        flash.now[:error] = "Please attach an invoice or supporting document."
        return render :new, layout: false, status: :unprocessable_entity
      end

      begin
        ActiveRecord::Base.transaction do
          @invoice.save!
          ::ReceiptService::Create.new(
            uploader: current_user,
            attachments:,
            upload_method: :transfer_create_page,
            receiptable: @invoice
          ).run!
        end
      rescue ActiveRecord::RecordInvalid => e
        flash.now[:error] = e.message
        return render :new, layout: false, status: :unprocessable_entity
      end

      Payroll::InvoiceMailer.with(invoice: @invoice).submitted.deliver_later
      flash[:success] = "Invoice submitted for review."
      redirect_to my_pay_path
    end

    private

    # Scope to positions where the signed-in user is the contractor, so a user
    # can only invoice their own engagements.
    def set_position
      @position = Payroll::Position.joins(:payee)
                                   .where(payees: { email: current_user.email })
                                   .find(params[:payroll_position_id])
    end

    def invoice_params
      params.require(:payroll_invoice).permit(:name, :amount, :description, file: [])
    end

  end
end
