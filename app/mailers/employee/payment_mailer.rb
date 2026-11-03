# frozen_string_literal: true

class Employee
  class PaymentMailer < ApplicationMailer
    before_action :set_payment
    before_action :set_delivery_reason, except: [:review_requested]

    def approved
      mail to: @employee.user.email_address_with_name, subject: "[Payroll] Approved: #{@payment.title}", from: hcb_email_with_name_of(@employee.event)
    end

    def rejected
      mail to: @employee.user.email_address_with_name, subject: "[Payroll] Rejected: #{@payment.title}", from: hcb_email_with_name_of(@employee.event)
    end

    def review_requested
      @delivery_reason = "you are on the team of #{@employee.event.name} on HCB."

      mail to: @employee.event.users.excluding(@employee.user).map(&:email_address_with_name),
           subject: "[Payroll / #{@employee.event.name}] Review Requested: #{@payment.title}"
    end

    def failed
      @reason = params[:reason]

      mail subject: "[Payroll] Transfer for #{@payment.title} failed to send", to: @employee.user.email_address_with_name
    end

    private

    def set_payment
      @payment = params[:payment]
      @employee = @payment.employee
    end

    def set_delivery_reason
      @delivery_reason = "you are being paid as a 1099 contractor by #{@employee.event.name}."
    end

  end

end
