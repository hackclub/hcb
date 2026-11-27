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

  # The charge's own cardholder sees the row links without being a member of
  # the organization, so the modals they open have to be rendered for them too
  context "for a charge with a pending transaction" do
    let(:cpt) { create(:canonical_pending_transaction, event: stripe_card.event, amount_cents: -1000, raw_pending_stripe_transaction: create(:raw_pending_stripe_transaction, stripe_card:, stripe_merchant_category_code: "5462")) }
    let(:ledger_item) { cpt.local_hcb_code.ledger_item }
    let(:cardholder) { ledger_item.author }
    let(:page) { Nokogiri::HTML5.fragment(rendered) }

    before do
      expect(cardholder).to eq(stripe_card.user)
      without_partial_double_verification do
        allow(view).to receive_messages(current_user: cardholder)
      end
    end

    it "offers the cardholder the charge details modal" do
      render partial: "ledger/items/linked_objects/card_charge", locals: { ledger_item: }

      expect(page.at_css(%([data-modal="verification_details_#{ledger_item.hashid}"]))).to be_present
      expect(page.at_css("#verification_details_#{ledger_item.hashid}").text).to include("Charge details")
    end

    it "opens the merchant and charge method details as modals in a popover too" do
      assign(:frame, true)

      render partial: "ledger/items/linked_objects/card_charge", locals: { ledger_item: }

      expect(page.css("details")).to be_empty
      expect(page.at_css(%([data-modal="merchant_details_#{ledger_item.hashid}"]))).to be_present
      expect(page.at_css("#merchant_details_#{ledger_item.hashid}").text).to include("Merchant details")
      expect(page.at_css(%([data-modal="verification_details_#{ledger_item.hashid}"]))).to be_present
      expect(page.at_css("#verification_details_#{ledger_item.hashid}")).to be_present
    end

    it "explains a decline in a popover" do
      cpt.decline!
      assign(:frame, true)

      render partial: "ledger/items/linked_objects/card_charge", locals: { ledger_item: ledger_item.reload }

      expect(page.at_css(%([data-modal="declined_information_#{ledger_item.hashid}"]))).to be_present
      expect(page.at_css("#declined_information_#{ledger_item.hashid}").text).to include("Transaction declined")
    end
  end
end
