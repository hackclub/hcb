# frozen_string_literal: true

require "rails_helper"

RSpec.describe PendingEventMappingEngine::Decline::Stripe do
  def create_pending_transaction(status:, approved: true)
    rpst = create(:raw_pending_stripe_transaction).tap do |rpst|
      rpst.update!(stripe_transaction: rpst.stripe_transaction.merge(status:, approved:, created: Time.now.to_i))
    end

    create(:canonical_pending_transaction, raw_pending_stripe_transaction: rpst)
  end

  it "releases authorizations Stripe expired, which it used to report as reversed" do
    expired = create_pending_transaction(status: "expired")
    reversed = create_pending_transaction(status: "reversed")
    pending = create_pending_transaction(status: "pending")
    captured = create_pending_transaction(status: "closed")

    described_class.new.run

    expect(expired.reload).to be_declined
    expect(reversed.reload).to be_declined
    expect(pending.reload).not_to be_declined
    expect(captured.reload).not_to be_declined
  end
end
