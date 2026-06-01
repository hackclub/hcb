# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::SendCardLockingNotificationJob, type: :job do
  it "accepts legacy scheduled jobs that still include an event keyword" do
    user = create(:user)
    service = instance_double(UserService::SendCardLockingNotification, run: true)

    allow(UserService::SendCardLockingNotification).to receive(:new).with(user:).and_return(service)

    expect {
      described_class.perform_now(user:, event: create(:event))
    }.not_to raise_error
  end
end
