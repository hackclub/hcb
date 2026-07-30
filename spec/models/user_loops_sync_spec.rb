# frozen_string_literal: true

require "rails_helper"

RSpec.describe "User Loops.so sync gating", type: :model do
  it "does not enqueue a Loops.so sync when an unverified user is updated" do
    user = create(
      :user,
      verified: false,
      creation_method: :first_robotics_form,
      full_name: "Unverified User",
    )

    initial_count = enqueued_jobs.count { |job| job[:job] == User::SyncUserToLoopsJob }

    user.update!(preferred_name: "anything")

    final_count = enqueued_jobs.count { |job| job[:job] == User::SyncUserToLoopsJob }

    expect(final_count).to eq(initial_count)
  end

  it "enqueues a Loops.so sync when a verified user is updated" do
    user = create(:user, verified: true)

    expect {
      user.update!(preferred_name: "anything")
    }.to change {
      enqueued_jobs.count { |job| job[:job] == User::SyncUserToLoopsJob }
    }.by(1)
  end
end
