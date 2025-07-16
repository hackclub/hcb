# frozen_string_literal: true

module TwilioMessageService
  class Send
    def initialize(user, body, hcb_code: nil)
      @user = user
      @body = body
      @hcb_code = hcb_code
    end

    def run!
      return if @user.phone_number.blank?

      client = Twilio::REST::Client.new(
        Credentials.fetch(:TWILIO, :ACCOUNT_SID),
        Credentials.fetch(:TWILIO, :AUTH_TOKEN)
      )

      twilio_response = client.messages.create(
        from: Credentials.fetch(:TWILIO, :PHONE_NUMBER),
        to: @user.phone_number,
        body: @body
      )

      # A bug prevents us from running to_json & storing the data directly
      # https://github.com/twilio/twilio-ruby/issues/555#issuecomment-1071039538
      raw_data = client.http_client.last_response.body

      sms_message = TwilioMessage.create!(
        to: @user.phone_number,
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
