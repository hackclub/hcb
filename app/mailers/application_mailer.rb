# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  OPERATIONS_EMAIL = "hcb@hackclub.com"

  DOMAIN = Credentials.fetch(:SMTP, :DOMAIN) || (Rails.env.production? ? "hackclub.com" : "staging.hcb.hackclub.com")
  USERNAME = Credentials.fetch(:SMTP, :USERNAME) || "hcb"

  default from: "HCB <#{USERNAME}@#{DOMAIN}>"
  layout "mailer/default"

  # allow usage of application helper
  helper :application

  protected

  def hcb_email_with_name_of(object)
    name = object.try(:name)
    if name.present?
      name += " via HCB"
    else
      name = "HCB"
    end
    email_address_with_name("#{USERNAME}@#{DOMAIN}", name)
  end

end
