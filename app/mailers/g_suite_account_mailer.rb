# frozen_string_literal: true

class GSuiteAccountMailer < ApplicationMailer
  # Everything here but `verify` mails a Google Workspace password. Listed as an
  # exclusion so a new action added to this mailer defaults to restricted.
  has_sensitive_contents except: [:verify]

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
