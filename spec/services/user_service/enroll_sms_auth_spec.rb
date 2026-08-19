# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserService::EnrollSmsAuth do
  def create_user_with_phone
    user = create(:user)
    user.update!(phone_number: "+18556254225")
    user
  end

  describe "#start_verification" do
    it "raises for users without an organizer position or card grant" do
      user = create_user_with_phone

      expect(TwilioVerificationService).not_to receive(:new)

      expect {
        described_class.new(user).start_verification
      }.to raise_error(UserService::EnrollSmsAuth::SMSEnrollmentError)
    end

    it "sends a verification request for users with an organizer position" do
      user = create_user_with_phone
      create(:organizer_position, user:)

      verification_service = instance_double(TwilioVerificationService)
      expect(verification_service).to receive(:send_verification_request).with(user.phone_number)
      expect(TwilioVerificationService).to receive(:new).and_return(verification_service)

      described_class.new(user).start_verification
    end

    it "sends a verification request for users with a card grant" do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)

      user = create_user_with_phone
      create(:card_grant, user:)

      verification_service = instance_double(TwilioVerificationService)
      expect(verification_service).to receive(:send_verification_request).with(user.phone_number)
      expect(TwilioVerificationService).to receive(:new).and_return(verification_service)

      described_class.new(user).start_verification
    end
  end

  describe "#enroll_sms_auth" do
    it "raises for users without an organizer position or card grant" do
      user = create_user_with_phone
      user.update!(phone_number_verified: true)

      expect {
        described_class.new(user).enroll_sms_auth
      }.to raise_error(UserService::EnrollSmsAuth::SMSEnrollmentError)

      expect(user.reload.use_sms_auth).to eq(false)
    end

    it "enables SMS auth for users with an organizer position" do
      user = create_user_with_phone
      create(:organizer_position, user:)
      user.update!(phone_number_verified: true)

      described_class.new(user).enroll_sms_auth

      expect(user.reload.use_sms_auth).to eq(true)
    end
  end
end
