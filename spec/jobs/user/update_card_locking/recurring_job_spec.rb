# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::UpdateCardLocking::RecurringJob, type: :job do
  let!(:first_user) { create(:user) }
  let!(:second_user) { create(:user) }

  let(:notified_users) { [] }

  before do
    allow(User).to receive(:card_locking_candidates).and_return(User.where(id: [first_user.id, second_user.id]))

    allow(UserService::SendCardLockingNotification).to receive(:new) do |user:|
      instance_double(UserService::SendCardLockingNotification, run: notified_users << user)
    end
  end

  def stub_update_card_locking(raising_for: nil)
    allow(UserService::UpdateCardLocking).to receive(:new) do |user:|
      instance_double(UserService::UpdateCardLocking).tap do |service|
        if user.id == raising_for&.id
          allow(service).to receive(:run).and_raise("Twilio is down")
        else
          allow(service).to receive(:run)
        end
      end
    end
  end

  it "evaluates locking and notifications for every candidate user" do
    stub_update_card_locking

    described_class.perform_now

    expect(notified_users.map(&:id)).to contain_exactly(first_user.id, second_user.id)
  end

  it "reports and moves on when one user raises, rather than starving the rest of the batch" do
    stub_update_card_locking(raising_for: first_user)
    allow(Rails.error).to receive(:report)

    described_class.perform_now

    expect(Rails.error).to have_received(:report).with(instance_of(RuntimeError), context: { user_id: first_user.id })
    expect(notified_users.map(&:id)).to eq([second_user.id])
  end
end
