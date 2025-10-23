# frozen_string_literal: true

module UserService
  class ExchangeLoginCodeForUser
    def initialize(user_id:, login_code:, sms: false)
      @user_id = user_id
      @login_code = login_code
      @sms = sms
    end

    def run
      if @sms
        exchange_login_code_by_sms
      else
        exchange_login_code_by_email
      end
    end

    private

    def exchange_login_code_by_sms
      login_code = @login_code.delete("-")
      user = User.find(@user_id)

      raise ::Errors::InvalidLoginCode if login_code.length != 6

      if TwilioVerificationService.new.check_verification_token(user.phone_number, login_code)
        user
      else
        raise ::Errors::InvalidLoginCode
      end
    end

    def exchange_login_code_by_email
      login_code = LoginCode.active.find_by(code: @login_code.delete("-"), user_id: @user_id)

      raise ::Errors::InvalidLoginCode if login_code.nil?
      raise ::Errors::InvalidLoginCode if login_code.created_at < (Time.current - 15.minutes)

      login_code.update(used_at: Time.current)

      login_code.user
    end

  end
end
