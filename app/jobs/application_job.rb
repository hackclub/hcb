# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # We don't use the Sidekiq adapter for tests which means this method isn't
  # available. To prevent `NoMethodError` exceptions on the job classes that
  # leverage this we stub it out.
  if Rails.env.test?
    def self.sidekiq_options(**); end
  end

  discard_on(Twilio::REST::RestError) do |job, error|
    Rails.error.report(error) unless TwilioMessageService::EXPECTED_TWILIO_ERRORS.any? { |code| error.message.include?("errors/#{code}") }
  end

end
