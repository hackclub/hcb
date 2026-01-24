# frozen_string_literal: true

module TwilioMessageService
  # Twilio errors we expect and don't need to report:
  # 21408, 21612: can't send text messages to certain countries (e.g. UK)
  # 60410: user has been flagged for fraud by Twilio
  EXPECTED_TWILIO_ERRORS = %w[21408 21612 60410].freeze

  class Send
    def initialize(user, body, hcb_code: nil, phone_number: nil)
      @user = user
      @body = body
      @hcb_code = hcb_code
      @phone_number = @user&.phone_number || phone_number
    end

    def run!
      return if @phone_number.blank?

      client = Twilio::REST::Client.new(
        Credentials.fetch(:TWILIO, :ACCOUNT_SID),
        Credentials.fetch(:TWILIO, :AUTH_TOKEN)
      )

      twilio_response = client.messages.create(
        from: Credentials.fetch(:TWILIO, :PHONE_NUMBER),
        to: @phone_number,
        body: @body
      )

      # A bug prevents us from running to_json & storing the data directly
      # https://github.com/twilio/twilio-ruby/issues/555#issuecomment-1071039538
      raw_data = client.http_client.last_response.body

      sms_message = TwilioMessage.create!(
        to: @phone_number,
        from: Credentials.fetch(:TWILIO, :PHONE_NUMBER),
        body: @body,
        twilio_sid: twilio_response.sid,
        twilio_account_sid: twilio_response.account_sid,
        raw_data:
      )

      OutgoingTwilioMessage.create!(
        twilio_message: sms_message,
        hcb_code: @hcb_code
      )

      sms_message
    rescue => e
      unless TwilioMessageService::EXPECTED_TWILIO_ERRORS.any? { |code| e.message.include?("errors/#{code}") }
        Rails.error.report(e)
        raise
      end
    end

  end
end
