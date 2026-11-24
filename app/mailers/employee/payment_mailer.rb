# frozen_string_literal: true

class Employee
  class PaymentMailer < ApplicationMailer
    def approved
      @payment = params[:payment]
      @employee = @payment.employee

      mail to: @employee.user.email_address_with_name, subject: "[Payroll] Approved: #{@payment.title}", from: hcb_email_with_name_of(@employee.event)
    end

    def rejected
      @payment = params[:payment]
      @employee = @payment.employee

      mail to: @employee.user.email_address_with_name, subject: "[Payroll] Rejected: #{@payment.title}", from: hcb_email_with_name_of(@employee.event)
    end

    def review_requested
      @payment = params[:payment]
      @employee = @payment.employee

      mail to: @employee.event.organizer_contact_emails(include_contact_email: false) { |users| users.excluding(@employee.user) },
           subject: "[Payroll / #{@employee.event.name}] Review Requested: #{@payment.title}"
    end

    def failed
      @payment = params[:payment]
      @employee = @payment.employee
      @reason = params[:reason]

      mail subject: "[Payroll] Transfer for #{@payment.title} failed to send", to: @employee.user.email_address_with_name
    end


  end

end
