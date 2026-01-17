# frozen_string_literal: true

module TwilioMessageService
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
    end

  end
end
