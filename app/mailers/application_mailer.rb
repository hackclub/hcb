# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  self.delivery_job = MailDeliveryJob

  OPERATIONS_EMAIL = "hcb@hackclub.com"

  ENGINEERING_EMAIL = "hcb-engr@hackclub.com"

  DOMAIN = Rails.env.production? ? "hackclub.com" : "staging.hcb.hackclub.com"
  default from: "HCB <hcb@#{DOMAIN}>"
  layout "mailer/default"

  # allow usage of application helper
  helper :application
  helper :logo

  # Every email says why the recipient is getting it: actions set
  # @delivery_reason and layouts/mailer/_footer renders it. Mailers that only
  # reach HCB staff opt out with `internal!`.
  class_attribute :internal_mailer, instance_accessor: false, default: false

  def self.internal!
    self.internal_mailer = true
  end

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
    # Earmuffing exists to suppress mail to specific real production users
    # (referenced by their production public_ids). In test and development
    # no real mail is delivered, so the filter has no job to do — and
    # running it in test is actively harmful: `usr_b9YtZb` hashid-decodes
    # to `User#id == 1`, and any test user that happens to land at that id
    # ends up memoized into this list, silently dropping that user's email
    # out of every subsequent mailer's recipients for the rest of the
    # process.
    return [] unless Rails.env.production?

    @earmuffed_recipients ||= EARMUFFED_USER_IDS.filter_map do |id|
      User.find_by_public_id(id)&.email
    end
  end

  def mail(...)
    if @delivery_reason.blank? && !self.class.internal_mailer
      Rails.error.unexpected("#{self.class.name}##{action_name} is sending without a @delivery_reason")
    end

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

  private

  # Mailer actions interpolate this into @delivery_reason, where view helpers
  # aren't available, so it delegates to the one copy in ApplicationHelper.
  def stripe_issuing_disclosure
    ApplicationController.helpers.stripe_issuing_disclosure
  end

  def receipts_delivery_reason
    "you spent funds with an HCB Visa® Commercial card and are required to upload receipts for all funds spent. #{stripe_issuing_disclosure}"
  end

end
