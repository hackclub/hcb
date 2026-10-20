# frozen_string_literal: true

# Delivers one copy of an email per recipient instead of a single message
# addressed to the whole list.
#
# Our SMTP provider rejects messages with more than 50 recipients
# ("554 Transaction failed: Recipient count exceeds 50"), so mailers that
# notify a whole organizer list include this concern and call
# `mail_individually` where they would otherwise call `mail to: list`:
#
#   class EventMailer < ApplicationMailer
#     include IndividualDelivery
#
#     def negative_balance
#       @emails = @event.organizer_contact_emails
#       mail_individually @emails, subject: "#{@event.name} has a negative balance"
#     end
#   end
#
# The caller's delivery method is honored:
#
#   * `deliver_later` enqueues the usual single job. When that job runs it
#     enqueues one MailDeliveryJob per recipient, so every copy is throttled
#     and retried on its own.
#   * `deliver_now` delivers each copy inline, straight away.
#
# Each copy is produced by re-running the same action with a `recipient`
# param, so actions using this concern must be free of side effects: create
# any records in the caller and pass them in as params.
#
# When the message is only inspected (mailer previews, specs reading
# `mail.to`), nothing is fanned out and the message is addressed to the whole
# list, exactly as `mail to:` would do.
module IndividualDelivery
  extend ActiveSupport::Concern

  RECIPIENT_PARAM = :recipient

  included do
    attr_accessor :individual_delivery_mode
  end

  class_methods do
    def with(params)
      Mailer.new(self, params)
    end
  end

  class Mailer < ActionMailer::Parameterized::Mailer
    private

    def method_missing(method_name, ...)
      if @mailer.action_methods.include?(method_name.name)
        MessageDelivery.new(@mailer, method_name, @params, ...)
      else
        super
      end
    end

    def respond_to_missing?(method, include_all = false)
      @mailer.respond_to?(method, include_all)
    end

  end

  class MessageDelivery < ActionMailer::Parameterized::MessageDelivery
    # :now when the caller used deliver_now, :later when MailDeliveryJob is
    # delivering from the queue, :inspect when the message is only being read.
    attr_writer :individual_delivery_mode

    def deliver_now
      @individual_delivery_mode ||= :now
      super
    end

    def deliver_now!
      @individual_delivery_mode ||= :now
      super
    end

    private

    def processed_mailer
      @processed_mailer ||= @mailer_class.new.tap do |mailer|
        mailer.params = @params
        mailer.individual_delivery_mode = @individual_delivery_mode || :inspect
        mailer.process @action, *@args
      end
    end

  end

  private

  def mail_individually(recipients, **headers, &block)
    raise ArgumentError, "pass the recipients as the first argument, not as to:" if headers.key?(:to)

    return mail(to: params[RECIPIENT_PARAM], **headers, &block) if params[RECIPIENT_PARAM].present?

    recipients = individual_recipients(recipients)

    case individual_delivery_mode
    when :later
      recipients.each { |recipient| individual_delivery(recipient).deliver_later }
    when :now
      recipients.each { |recipient| individual_delivery(recipient).deliver_now }
    when :inspect
      mail(to: recipients, **headers, &block)
    else
      # Only #{self.class}.with(...) routes through IndividualDelivery::MessageDelivery;
      # a bare #{self.class}.action call would send one message to everyone.
      raise ArgumentError, "#{self.class.name} must be called with params (#{self.class.name}.with(...).#{action_name})"
    end
  end

  def individual_delivery(recipient)
    self.class.with(params.merge(RECIPIENT_PARAM => recipient)).public_send(action_name)
  end

  # Dedupes by address and applies the same earmuffing as ApplicationMailer#mail:
  # earmuffed users are left out of group emails unless nobody else is left.
  def individual_recipients(recipients)
    recipients = Array(recipients).compact_blank.uniq { |recipient| email_address_of(recipient) }
    earmuffed = self.class.earmuffed_recipients.map(&:downcase)
    kept = recipients.reject { |recipient| earmuffed.include?(email_address_of(recipient)) }
    kept.empty? ? recipients : kept
  end

  def email_address_of(recipient)
    Mail::Address.new(recipient.to_s).address.to_s.downcase
  rescue Mail::Field::ParseError
    recipient.to_s.downcase
  end

end
