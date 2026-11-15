# frozen_string_literal: true

class CheckDepositMailer < ApplicationMailer
  def rejected
    @check_deposit = params[:check_deposit]

    mail to: @check_deposit.created_by.email_address_with_name, subject: "Your check failed to deposit"
  end

  def returned
    @check_deposit = params[:check_deposit]

    mail to: @check_deposit.created_by.email_address_with_name, subject: "Your check deposit was returned"
  end

  def deposited
    @check_deposit = params[:check_deposit]

    mail to: @check_deposit.created_by.email_address_with_name, subject: "Your check has deposited!"
  end

end
