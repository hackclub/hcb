# frozen_string_literal: true

class MailDeliveryJob < ActionMailer::MailDeliveryJob
  unless Rails.env.test?
    throttle threshold: 12, period: 1.second
  end

end
