# frozen_string_literal: true

class MailDeliveryJob < ActionMailer::MailDeliveryJob
  unless Rails.env.test?
    # AWS max send rate is 14/second - throttling at 10 to provide a buffer
    throttle threshold: 10, period: 1.second
  end

  # Same as ActionMailer::MailDeliveryJob#perform, plus telling mailers that
  # include IndividualDelivery that they are being delivered from the queue,
  # so they fan out into one job per recipient instead of sending inline.
  def perform(mailer, mail_method, delivery_method, args:, kwargs: nil, params: nil)
    mailer_class = params ? mailer.constantize.with(params) : mailer.constantize
    message = if kwargs
                mailer_class.public_send(mail_method, *args, **kwargs)
              else
                mailer_class.public_send(mail_method, *args)
              end
    message.individual_delivery_mode = :later if message.is_a?(IndividualDelivery::MessageDelivery)
    message.send(delivery_method)
  end

end
