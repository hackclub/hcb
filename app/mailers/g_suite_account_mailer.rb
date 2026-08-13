# frozen_string_literal: true

class GSuiteAccountMailer < ApplicationMailer
  # `verify` carries no password, so it stays visible.
  has_sensitive_contents only: [:notify_user_of_activation, :notify_user_of_reset]

  def verify
    @recipient = params[:recipient]

    mail to: @recipient,
         subject: "[Action Requested] Verify your HCB Google Workspace account"
  end

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
