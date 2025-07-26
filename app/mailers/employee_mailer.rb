# frozen_string_literal: true

class EmployeeMailer < ApplicationMailer
  def invitation
    @employee = params[:employee]

    mail to: @employee.user.email_address_with_name, subject: "Get paid by #{@employee.event.name} as a 1099 contractor", from: hcb_email_with_name_of(@employee.event)
  end

end
