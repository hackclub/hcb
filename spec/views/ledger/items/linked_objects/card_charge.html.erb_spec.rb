# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ledger/items/linked_objects/_card_charge" do
  let(:stripe_card) { create(:stripe_card, :with_stripe_id) }
  let(:ledger_item) { create(:ledger_item, linked_object: card_charge) }

  # View specs have no signed-in user for Pundit's `policy` helper, so every
  # policy check answers false.
  let(:denying_policy) do
    Class.new do
      def method_missing(*) = false

      def respond_to_missing?(*) = true
    end.new
  end

  # Session helpers come from the controller, so a view spec has none.
  before do
    without_partial_double_verification do
      allow(view).to receive_messages(policy: denying_policy, current_user: nil, organizer_signed_in?: false)
    end
  end

  context "when the merchant charged in a foreign currency" do
    let(:card_charge) do
      create(:raw_pending_stripe_transaction, stripe_card:, stripe_transaction: {
               "card"              => { "id" => stripe_card.stripe_id },
               "cardholder"        => stripe_card.stripe_cardholder.stripe_id,
               "merchant_amount"   => -1234,
               "merchant_currency" => "eur",
               "merchant_data"     => { "name" => "Boulangerie", "category" => "bakeries" }
             }).reload.card_charge
    end

    it "shows what the merchant charged in their currency" do
      render partial: "ledger/items/linked_objects/card_charge", locals: { ledger_item: }

      expect(rendered).to include("Charged in EUR")
      expect(rendered).to include("€12.34 EUR")
    end
  end

  context "when the merchant charged in USD" do
    let(:card_charge) { create(:raw_pending_stripe_transaction, stripe_card:).reload.card_charge }

    it "omits the merchant currency row" do
      render partial: "ledger/items/linked_objects/card_charge", locals: { ledger_item: }

      expect(rendered).not_to include("Charged in")
    end
  end
end
