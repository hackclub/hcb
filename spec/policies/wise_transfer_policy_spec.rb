# frozen_string_literal: true

require "rails_helper"

RSpec.describe WiseTransferPolicy, type: :policy do
  let(:event) { create(:event) }
  let(:manager) { create(:user) }
  let(:admin) { create(:user, :make_admin) }

  before do
    create(:organizer_position, event:, user: manager, role: :manager)
  end

  # Build (don't persist) so the `after_create` callback — which reaches
  # out to the Wise API to generate a quote — doesn't fire. The policy
  # only reads the record's event and aasm_state.
  def wise_transfer(aasm_state:)
    WiseTransfer.new(
      event:,
      user: manager,
      aasm_state:,
      amount_cents: 100_00,
      currency: "CAD",
      payment_for: "Reimbursement",
      recipient_name: "Jane Doe",
      recipient_email: "jane@example.com",
      recipient_country: :CA
    )
  end

  describe "#mark_failed?" do
    context "when the transfer has not been sent yet" do
      %w[pending approved].each do |state|
        it "allows an organization manager to mark a #{state} transfer as failed" do
          policy = described_class.new(manager, wise_transfer(aasm_state: state))
          expect(policy.mark_failed?).to be true
        end
      end
    end

    context "when the transfer has already been sent" do
      # Regression test for a security report: an org manager could mark an
      # already-sent Wise transfer as failed. Doing so declines the canonical
      # pending transaction and refunds the money to the org's balance — even
      # though the funds had already physically left via Wise. Only HCB admins
      # should be able to mark a sent transfer as failed.
      it "does NOT allow an organization manager to mark it as failed" do
        policy = described_class.new(manager, wise_transfer(aasm_state: "sent"))
        expect(policy.mark_failed?).to be false
      end

      it "still allows an HCB admin to mark it as failed" do
        policy = described_class.new(admin, wise_transfer(aasm_state: "sent"))
        expect(policy.mark_failed?).to be true
      end
    end

    context "when the transfer has already been deposited" do
      it "does NOT allow an organization manager to mark it as failed" do
        policy = described_class.new(manager, wise_transfer(aasm_state: "deposited"))
        expect(policy.mark_failed?).to be false
      end
    end
  end
end
