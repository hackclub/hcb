# frozen_string_literal: true

require "rails_helper"

describe LoginCodeService::Request do
  let(:ip_address) { "127.0.0.1" }
  let(:user_agent) { "fake firefox" }

  context "when a user with a given email does not exist" do
    it "creates that user with login code and emails" do
      new_email = "test@example.com"
      expect(User.find_by(email: new_email)).to be_nil

      expect(LoginCodeMailer).to receive_message_chain(:send_code, :deliver_now)
      response = nil
      expect do
        response = described_class.new(email: new_email,
                                       ip_address:,
                                       user_agent:).run
      end.to change { User.count }.by(1)

      user = User.find_by(email: new_email)
      expect(user.login_codes.count).to eq(1)
      login_code = user.login_codes.first
      expect(login_code.ip_address).to eq(ip_address)
      expect(login_code.user_agent).to eq(user_agent)

      expect(response).to eq({
                               id: user.id,
                               email: user.email,
                               status: "login code sent",
                               method: :email,
                               login_code:
                             })
    end
  end


  context "when a user with a given email does exist" do
    it "creates that user with login code and emails" do
      user = create(:user)

      expect(LoginCodeMailer).to receive_message_chain(:send_code, :deliver_now)
      response = nil
      expect do
        response = described_class.new(email: user.email,
                                       ip_address:,
                                       user_agent:).run
      end.to change { User.count }.by(0)

      expect(user.login_codes.count).to eq(1)
      login_code = user.login_codes.first
      expect(login_code.ip_address).to eq(ip_address)
      expect(login_code.user_agent).to eq(user_agent)

      expect(response).to eq({
                               id: user.id,
                               email: user.email,
                               status: "login code sent",
                               method: :email,
                               login_code:
                             })
    end
  end

  context "errors" do
    context "when user has an error" do
      it "does not save the user, does not create a login code and returns an error" do
        invalid_email = "bad@bad"
        expect(LoginCodeMailer).not_to receive(:send_code)

        response = nil
        expect do
          response = described_class.new(email: invalid_email,
                                         ip_address:,
                                         user_agent:).run
        end.to change { User.count }.by(0)

        expect(LoginCode.count).to eq(0)
        expect(response[:error].attribute_names).to eq([:email])
      end
    end
  end
end
