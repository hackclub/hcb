# frozen_string_literal: true

class User
  class SendSmsJob < ApplicationJob
    queue_as :low

    def perform(user_id:, body:)
      user = User.find_by(id: user_id)
      return unless user&.phone_number.present? && user.phone_number_verified?

      TwilioMessageService::Send.new(user, body).run!
    end

  end

end
