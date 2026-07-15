# frozen_string_literal: true

class CheckDepositMailer < ApplicationMailer
  before_action :set_delivery_reason
  
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

  private

  def set_delivery_reason
    @delivery_reason = "you submitted a check deposit for #{@check_deposit.event.name}."
  end

end
