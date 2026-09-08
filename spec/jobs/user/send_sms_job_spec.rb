# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::SendSmsJob do
  # `phone_number_verified` is force-reset to false whenever `phone_number` changes
  # (see User#on_phone_number_update), so it must be set in a separate update.
  let(:user) do
    create(:user, phone_number: "+18556254225").tap { |u| u.update!(phone_number_verified: true) }
  end

  it "sends an SMS to a verified user" do
    sender = instance_double(TwilioMessageService::Send, run!: true)
    expect(TwilioMessageService::Send).to receive(:new).with(user, "hi").and_return(sender)

    described_class.perform_now(user_id: user.id, body: "hi")
  end

  it "does not send an SMS to an unverified user" do
    user.update!(phone_number_verified: false)

    expect(TwilioMessageService::Send).not_to receive(:new)

    described_class.perform_now(user_id: user.id, body: "hi")
  end

  it "does not raise for a missing user id" do
    expect(TwilioMessageService::Send).not_to receive(:new)

    expect { described_class.perform_now(user_id: -1, body: "hi") }.not_to raise_error
  end
end
