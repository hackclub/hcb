# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  self.delivery_job = MailDeliveryJob

  OPERATIONS_EMAIL = "hcb@hackclub.com"

  DOMAIN = Rails.env.production? ? "hackclub.com" : "staging.hcb.hackclub.com"
  default from: "HCB <hcb@#{DOMAIN}>"
  layout "mailer/default"

  after_action :prevent_noisy_delivery

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

  EARMUFFED_USER_IDS = [
    "usr_b9YtZb", # Zach
    "usr_b6mtLG", # Christina
    "usr_N4tk5d", # Rachel A (personal)
    "usr_ZBt5g5", # Rachel A (Hack Club)
  ].freeze

  def self.earmuffed_recipients
    @earmuffed_recipients ||= EARMUFFED_USER_IDS.filter_map do |id|
      User.find_by_public_id(id)&.email
    end
  end

  def prevent_noisy_delivery
    remaining_recipients = mail.to - self.class.earmuffed_recipients

    if remaining_recipients.blank?
      # If there are no recipients left (e.g. direct email to earmuffed recipient,
      # or all recipients are earmuffed), then send the email normally.
      return
    end

    mail.to = remaining_recipients
  end

end
