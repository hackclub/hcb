# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  self.delivery_job = MailDeliveryJob

  OPERATIONS_EMAIL = "hcb@hackclub.com"

  DOMAIN = Rails.env.production? ? "hackclub.com" : "staging.hcb.hackclub.com"
  default from: "HCB <hcb@#{DOMAIN}>"
  layout "mailer/default"

  # allow usage of application helper
  helper :application

  def self.deliver_mail(mail)
    # Our SMTP service will throw an error if we attempt
    # to deliver an email without recipients. Occasionally
    # that happens due to events without members. This
    # will prevent those attempts from being made.
    return if mail.recipients.compact.empty?

    super(mail)
  end

  protected

  def hcb_email_with_name_of(object)
    name = object.try(:name)
    if name.present?
      name += " via HCB"
    else
      name = "HCB"
    end

    email_address_with_name("hcb@hackclub.com", name)
  end

  def no_recipients?
    mail.recipients.compact.empty?
  end

end
