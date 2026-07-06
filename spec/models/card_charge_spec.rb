# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardCharge, type: :model do
  describe "creating a RawPendingStripeTransaction" do
    it "creates a CardCharge for the authorization" do
      rpst = create(:raw_pending_stripe_transaction)

      charge = rpst.card_charge
      expect(charge).to be_present
      expect(charge.raw_stripe_transactions).to be_empty
    end

    it "claims an existing charge when the settled transaction arrived first" do
      rst = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_arrived_first")
      charge = rst.card_charge
      expect(charge.raw_pending_stripe_transaction).to be_nil

      rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_arrived_first")

      expect(rpst.card_charge).to eq(charge)
      expect(charge.reload.raw_pending_stripe_transaction).to eq(rpst)
    end
  end

  describe "creating a RawStripeTransaction" do
    it "joins the authorization's charge when it settles" do
      rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_settles")
      rst = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_settles")

      expect(rst.card_charge).to eq(rpst.card_charge)
      expect(rpst.card_charge.raw_stripe_transactions).to contain_exactly(rst)
    end

    it "groups multi-captures and refunds of the same authorization into one charge" do
      rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_multi")
      first_capture = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_multi")
      second_capture = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_multi")

      charge = rpst.card_charge
      expect(charge.raw_stripe_transactions).to contain_exactly(first_capture, second_capture)
    end

    it "creates a standalone charge for a force capture (no authorization)" do
      rst = create(:raw_stripe_transaction, stripe_authorization_id: nil)

      charge = rst.card_charge
      expect(charge).to be_present
      expect(charge.raw_pending_stripe_transaction).to be_nil
      expect(charge.raw_stripe_transactions).to contain_exactly(rst)
    end

    it "does not group force captures with each other" do
      first = create(:raw_stripe_transaction, stripe_authorization_id: nil)
      second = create(:raw_stripe_transaction, stripe_authorization_id: nil)

      expect(first.card_charge).not_to eq(second.card_charge)
    end

    it "groups settled transactions sharing an authorization even before it is imported" do
      first = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_pending_missing")
      second = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_pending_missing")

      expect(first.card_charge).to eq(second.card_charge)
      expect(first.card_charge.raw_pending_stripe_transaction).to be_nil
    end
  end

  describe ".link_raw_pending_stripe_transaction!" do
    it "is idempotent" do
      rpst = create(:raw_pending_stripe_transaction)
      charge = rpst.card_charge

      expect { CardCharge.link_raw_pending_stripe_transaction!(rpst.reload) }.not_to change(CardCharge, :count)
      expect(rpst.card_charge).to eq(charge)
    end
  end

  describe ".link_raw_stripe_transaction!" do
    it "is idempotent" do
      rst = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_idempotent")
      charge = rst.card_charge

      expect { CardCharge.link_raw_stripe_transaction!(rst.reload) }.not_to change(CardCharge, :count)
      expect(rst.reload.card_charge).to eq(charge)
      expect(charge.raw_stripe_transactions.count).to eq(1)
    end
  end
end
