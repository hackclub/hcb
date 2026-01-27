# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  self.delivery_job = MailDeliveryJob

  OPERATIONS_EMAIL = "hcb@hackclub.com"

  DOMAIN = Rails.env.production? ? "hackclub.com" : "staging.hcb.hackclub.com"
  default from: "HCB <hcb@#{DOMAIN}>"
  layout "mailer/default"

  # allow usage of application helper
  helper :application
  helper :logo

  def self.deliver_mail(mail)
    # Our SMTP service will throw an error if we attempt
    # to deliver an email without recipients. Occasionally
    # that happens due to events without members. This
    # will prevent those attempts from being made.
    return if mail.recipients.compact.empty?

    super(mail)
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

  def mail(...)
    super(...).tap do |msg|
      new_to = (msg.to || []) - self.class.earmuffed_recipients
      new_cc = (msg.cc || []) - self.class.earmuffed_recipients
      new_bcc = (msg.bcc || []) - self.class.earmuffed_recipients

      all_recipients = new_to + new_cc + new_bcc

      unless all_recipients.empty? || Rails.env.development?
        msg.to = new_to
        msg.cc = new_cc
        msg.bcc = new_bcc
      end
    end
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
