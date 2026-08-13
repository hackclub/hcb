# frozen_string_literal: true

require "rails_helper"

RSpec.describe "sensitive email history", type: :mailer do
  def message_for(mail)
    expect { mail.deliver_now }.to change(Ahoy::Message, :count).by(1)

    Ahoy::Message.order(:id).last
  end

  it "marks login code emails as sensitive" do
    message = message_for(LoginCodeMailer.send_code("someone@example.invalid", "481-209"))

    expect(message).to be_sensitive
  end

  it "marks Google Workspace password emails as sensitive" do
    message = message_for(
      GSuiteAccountMailer.notify_user_of_reset(
        recipient: "someone@example.invalid",
        address: "someone@example.invalid",
        password: "a-real-password"
      )
    )

    expect(message).to be_sensitive
  end

  it "does not mark the Google Workspace verification email as sensitive" do
    message = message_for(GSuiteAccountMailer.with(recipient: "someone@example.invalid").verify)

    expect(message).not_to be_sensitive
  end

  it "marks email change emails as sensitive" do
    user = create(:user)
    request = User::EmailUpdate.new(
      user:,
      updated_by: user,
      original: user.email,
      replacement: "replacement-#{SecureRandom.hex(4)}@example.invalid"
    )
    request.validate # populates the authorization and verification tokens

    expect(message_for(User::EmailUpdateMailer.authorization(request))).to be_sensitive
    expect(message_for(User::EmailUpdateMailer.verification(request))).to be_sensitive
  end

  it "leaves undeclared mailers visible" do
    message = message_for(UserMailer.onboarded(user: create(:user)))

    expect(message).not_to be_sensitive
  end
end
