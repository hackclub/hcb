# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # We don't use the Sidekiq adapter for tests which means this method isn't
  # available. To prevent `NoMethodError` exceptions on the job classes that
  # leverage this we stub it out.
  if Rails.env.test?
    def self.sidekiq_options(**); end
  end

  # Twilio errors we expect and don't need to report:
  # 21408, 21612: can't send text messages to certain countries (e.g. UK)
  # 60410: user has been flagged for fraud by Twilio
  EXPECTED_TWILIO_ERRORS = %w[21408 21612 60410].freeze

  discard_on(Twilio::REST::RestError) do |job, error|
    Rails.error.report(error) unless EXPECTED_TWILIO_ERRORS.any? { |code| error.message.include?("errors/#{code}") }
  end

end
