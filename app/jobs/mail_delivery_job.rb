# frozen_string_literal: true

class MailDeliveryJob < ActionMailer::MailDeliveryJob
  # If a record referenced by a mailer (e.g. `comment:`) is deleted before this
  # job runs, GlobalID deserialization of the job's arguments raises this -
  # there's no mail worth sending for a record that no longer exists.
  discard_on ActiveJob::DeserializationError

  unless Rails.env.test?
    # AWS max send rate is 14/second - throttling at 10 to provide a buffer
    throttle threshold: 10, period: 1.second
  end

end
