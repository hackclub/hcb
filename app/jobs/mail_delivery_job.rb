# frozen_string_literal: true

class MailDeliveryJob < ApplicationJob
  throttle threshold: 12, period: 1.second

  def perform(mailer, mail_method, delivery_method, args:, kwargs: nil, params: nil)
    ActionMailer::MailDeliveryJob.perform_now(mailer, mail_method, delivery_method, args:, kwargs:, params:)
  end

end
