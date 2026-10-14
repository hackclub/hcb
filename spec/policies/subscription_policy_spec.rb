# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriptionPolicy, type: :policy do
  let(:subscription) { create(:subscription) }
  let(:event) { subscription.event }

  def policy_for(user)
    described_class.new(user, subscription)
  end

  def user_with_role(role)
    create(:user).tap { |user| create(:organizer_position, user:, event:, role:) }
  end

  it "lets readers view but not change subscriptions" do
    policy = policy_for(user_with_role(:reader))

    expect(policy.show?).to be(true)
    expect(policy.create?).to be(false)
    expect(policy.update?).to be(false)
    expect(policy.cancel?).to be(false)
    expect(policy.destroy?).to be(false)
  end

  it "lets members manage subscriptions" do
    policy = policy_for(user_with_role(:member))

    expect(policy.show?).to be(true)
    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.cancel?).to be(true)
    expect(policy.destroy?).to be(true)
  end

  it "lets auditors view subscriptions" do
    expect(policy_for(create(:user, access_level: :auditor)).show?).to be(true)
  end

  it "doesn't let other users view subscriptions" do
    expect(policy_for(create(:user)).show?).to be(false)
    expect(policy_for(nil).show?).to be(false)
  end

  it "shows the organization's subscriptions to readers" do
    expect(EventPolicy.new(user_with_role(:reader), event).subscriptions?).to be(true)
    expect(EventPolicy.new(create(:user), event).subscriptions?).to be(false)
  end
end
