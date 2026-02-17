# frozen_string_literal: true

module UserService
  class EnrollSmsAuth
    class SMSEnrollmentError < StandardError
    end

    def initialize(user)
      @user = user
    end

    # Starts the phone number verification by sending a challenge text
    def start_verification
      # This shouldn't be possible because to enroll in SMS auth, your phone number should be reformatted already
      # doing this here to be safe.
      raise ArgumentError.new("phone number for user: #{@user.id} not in E.164 format") unless @user.phone_number =~ /\A\+[1-9]\d{1,14}\z/

      disallow_fresh_users

      TwilioVerificationService.new.send_verification_request(@user.phone_number)
    end

    # Completing the phone number verification by checking that exchanging code works
    def complete_verification(verification_code)
      disallow_fresh_users

      begin
        verified = TwilioVerificationService.new.check_verification_token(@user.phone_number, verification_code)
      rescue Twilio::REST::RestError
        raise ::Errors::InvalidLoginCode, "invalid login code"
      end
      raise ::Errors::InvalidLoginCode, "invalid login code" if !verified

      # save all our fields
      @user.phone_number_verified = true
      @user.save!
    end

    def enroll_sms_auth
      raise SMSEnrollmentError, "user has no phone number" if @user.phone_number.blank?
      raise SMSEnrollmentError, "user has not verified phone number" unless @user.phone_number_verified

      disallow_fresh_users

      @user.use_sms_auth = true
      @user.save!
    end

    def disable_sms_auth
      @user.use_sms_auth = false
      @user.save!
    end

    private

    def disallow_fresh_users
      return if @user.created_at < 1.day.ago

      raise SMSEnrollmentError, "Please wait at least 24 hours after creating your account before enrolling in SMS authentication."
    end

  end
end
