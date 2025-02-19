# frozen_string_literal: true

class Employee
  class PaymentsController < ApplicationController
    include SetEvent

    def create
      @employee = Employee.find(employee_payment_params[:employee_id])
      @payment = @employee.payments.build(employee_payment_params)

      authorize @payment
      if @payment.save
        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments: params[:employee_payment][:file],
          upload_method: :employee_payment,
          receiptable: @payment
        ).run!
        redirect_to my_payroll_path, flash: { success: "Payment successfully requested." }
      else
        redirect_to my_payroll_path, flash: { error: @payment.errors.full_messages.to_sentence }
      end
    end

    def review
      @payment = Employee::Payment.find(params[:payment_id])
      authorize @payment
      @payment.update(review_message: params[:review_message]) if params[:review_message]
      @payment.update(reviewed_by: current_user)
      if params[:approved]
        @payment.mark_organizer_approved!
        redirect_to event_employees_path(@payment.employee.event), flash: { success: "Payment approved." }
      elsif params[:rejected]
        @payment.mark_rejected!
        redirect_to event_employees_path(@payment.employee.event), flash: { success: "Payment rejected, successfully." }
      end
    end

    private

    def employee_payment_params
      params.require(:employee_payment).permit(:employee_id, :amount, :title)
    end

  end

end
