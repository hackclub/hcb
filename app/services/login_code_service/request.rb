# frozen_string_literal: true

module LoginCodeService
  class Request
    # Far above what a person retrying login needs; far below what makes a
    # pumped premium number pay.
    DAILY_SMS_LIMIT = 10

    def initialize(email:, ip_address:, user_agent:, sms: false)
      @email = email
      @sms = sms
      @ip_address = ip_address
      @user_agent = user_agent
    end

    def run
      user = User.find_or_initialize_by(email: @email)

      if @sms
        send_login_code_by_sms(user)
      else
        send_login_code_by_email(user)
      end
    end

    def send_login_code_by_sms(user)
      return { error: "no phone number provided", method: :sms } if user.phone_number.empty?

      # Turnstile gates the zero-factor login form, but this service is also
      # reachable once a factor has cleared and from sudo-mode
      # reauthentication, where no widget runs. Cap what a single account can
      # spend in a day so a once-verified premium number can't be pumped
      # through those paths. Mirrors
      # `UserService::EnrollSmsAuth#disallow_excessive_sms_verifications`.
      return send_login_code_by_email(user) if daily_sms_limit_reached?(user)

      begin
        TwilioVerificationService.new.send_verification_request(user.phone_number)
      rescue
        return send_login_code_by_email(user)
      end

      {
        id: user.id,
        email: user.email,
        status: "login code sent",
        method: :sms
      }
    end

    def send_login_code_by_email(user)
      user.save if user.new_record?
      if user.new_record? && !user.save
        return { error: user.errors, method: :email }
      end

      login_code = user.login_codes.create(
        ip_address: @ip_address,
        user_agent: @user_agent
      )

      LoginCodeMailer.send_code(user.email_address_with_name, login_code.pretty).deliver_now

      {
        id: user.id,
        email: user.email,
        status: "login code sent",
        method: :email,
        login_code:
      }
    end

    private

    def daily_sms_limit_reached?(user)
      cache_key = "login_sms_count:#{user.id}:#{Date.current}"
      count = Rails.cache.increment(cache_key, 1, expires_in: 25.hours).to_i

      return false if count <= DAILY_SMS_LIMIT

      Rails.error.report(Errors::TwilioAbuseError.new("User #{user.id} exceeded login SMS send limit (count: #{count})."))
      true
    end

  end
end
