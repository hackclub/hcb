# frozen_string_literal: true

class MailDeliveryJob < ActionMailer::MailDeliveryJob
  unless Rails.env.test?
    # AWS max send rate is 14/second - throttling at 10 to provide a buffer
    throttle threshold: 10, period: 1.second
  end

end
