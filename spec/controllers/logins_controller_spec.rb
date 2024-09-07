# frozen_string_literal: true

require "rails_helper"

describe LoginsController do
  describe "#login_code" do
    context "when not sent by sms" do
      it "calls LoginCodeService::Request but does not call twilio" do
        expect(LoginCodeService::Request).to receive(:new).and_call_original
        expect(TwilioVerificationService).to_not receive(:new)
        user = create(:user)
        params = {
          email: user.email,
          id: user.logins.create.hashid,
          method: :login_code
        }

        post :login_code, params:
      end
    end

    context "when sent by sms" do
      it "calls LoginCodeService::Request service in bank (which in turns calls twilio)" do
        expect(LoginCodeService::Request).to receive(:new).and_call_original
        expect(TwilioVerificationService).to receive_message_chain(:new, :send_verification_request) # this also stubs the call so it won't actually call Twilio's API

        user = create(:user, phone_number: "+18005555555")
        # need to update after the fact because of User callback on_phone_number_update resetting this value
        user.update(use_sms_auth: true)
        params = {
          email: user.email,
          id: user.logins.create.hashid,
          method: :login_code
        }

        post :login_code, params:
      end
    end
  end
end
