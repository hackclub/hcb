# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ledger/items/linked_objects/_ach_transfer" do
  let(:event) { create(:event, :with_positive_balance) }
  let(:ach_transfer) { create(:ach_transfer, event:) }
  let(:ledger_item) { ach_transfer.reload.ledger_item }

  # View specs have no signed-in user for Pundit's `policy` helper, so every
  # policy check answers false.
  let(:denying_policy) do
    Class.new do
      def method_missing(*) = false

      def respond_to_missing?(*) = true
    end.new
  end

  before do
    without_partial_double_verification do
      allow(view).to receive(:policy).and_return(denying_policy)
    end
  end

  it "links the payment the transfer pays out" do
    payment = create(:payment, payee: create(:payee, event:))
    create(:payment_attempt, :ach, payment:, payout: ach_transfer)

    render partial: "ledger/items/linked_objects/ach_transfer", locals: { ledger_item: }

    expect(rendered).to include("Associated payment")
    expect(rendered).to include(payment_path(payment))
  end

  it "omits the associated payment when the transfer was sent on its own" do
    render partial: "ledger/items/linked_objects/ach_transfer", locals: { ledger_item: }

    expect(rendered).not_to include("Associated payment")
  end
end
