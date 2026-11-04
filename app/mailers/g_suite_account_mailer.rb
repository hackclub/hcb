# frozen_string_literal: true

class GSuiteAccountMailer < ApplicationMailer
  def notify_user_of_activation(params)
    @recipient = params[:recipient]
    @address = params[:address]
    @password = params[:password]
    @event = params[:event]

    mail to: @recipient,
         subject: "Your Google Workspace account via HCB is ready!"
  end

  def notify_user_of_reset(params)
    @recipient = params[:recipient]
    @address = params[:address]
    @password = params[:password]

    mail to: @recipient,
         subject: "Your HCB Google Workspace password was reset"
  end

end
