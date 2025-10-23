# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserService::ExchangeLoginCodeForUser, type: :model do
  let(:login_code) { create(:login_code) }
  let(:user) { login_code.user }

  let(:service) {
    UserService::ExchangeLoginCodeForUser.new(
      user_id: user.id,
      login_code: login_code.code,
      sms:,
    )
  }

  let(:exchange_login_code_error_resp) do
    {
      errors: ["error"]
    }
  end

  context "email" do
    let(:sms) { false }

    context "when sent by email" do
      it "exchanges login code for user in hcb" do
        exchanged_user = service.run
        expect(exchanged_user).to eq(user)
      end
    end

    context "when login code doesn't exist" do
      let(:service) {
        UserService::ExchangeLoginCodeForUser.new(
          user_id: user.id,
          login_code: "does not exist",
          sms:
        )
      }

      it "raises error" do
        expect do
          service.run
        end.to raise_error(::Errors::InvalidLoginCode)
      end
    end

  end

  context "sms" do
    let(:sms) { true }

    context "when sent by sms" do
      it "calls twilio" do
        expect(TwilioVerificationService).to receive_message_chain(:new, :check_verification_token).and_return(true)

        exchanged_user = service.run
        expect(exchanged_user).to eq(user)
      end
    end
  end
end
