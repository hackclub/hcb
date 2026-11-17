# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillCardChargeAuthorizationMethodsTask do
  def run_task
    task = described_class.new
    task.collection.each { |batch| task.process(batch) }
  end

  it "copies each charge's authorization method from its authorization" do
    card_charge = create(:raw_pending_stripe_transaction, authorization_method: "swipe").card_charge
    card_charge.update_column(:authorization_method, nil)

    run_task

    expect(card_charge.reload.authorization_method).to eq("swipe")
  end

  it "leaves charges without an authorization alone" do
    card_charge = create(:raw_stripe_transaction, stripe_authorization_id: nil).card_charge

    run_task

    expect(card_charge.reload.authorization_method).to be_nil
  end
end
