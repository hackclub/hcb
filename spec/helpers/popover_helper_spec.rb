# frozen_string_literal: true

require "rails_helper"

RSpec.describe PopoverHelper, type: :helper do
  describe "#stripe_card_popover_data" do
    let(:stripe_card) { create(:stripe_card, :with_stripe_id) }

    before { allow(helper).to receive(:auditor_signed_in?).and_return(false) }

    it "opens a regular card in the popover" do
      data = helper.stripe_card_popover_data(stripe_card)

      expect(data[:modal]).to eq("shared_popover")
      expect(data[:popover_src]).to eq(stripe_card.popover_path)
      expect(data[:popover_frame_id]).to eq("stripe_card_#{stripe_card.public_id}")
    end

    context "with a grant card" do
      before do
        allow_any_instance_of(CardGrant).to receive(:transfer_money)
        create(:card_grant, stripe_card:)
      end

      # StripeCardsController#show redirects non-auditors to the card grant page,
      # which has no turbo frame for the popover to load, so the card has to open
      # as a full page.
      it "skips the popover for non-auditors" do
        expect(helper.stripe_card_popover_data(stripe_card)).to eq({ turbo_frame: "_top" })
      end

      it "keeps the popover for auditors, who stay on the card page" do
        allow(helper).to receive(:auditor_signed_in?).and_return(true)

        data = helper.stripe_card_popover_data(stripe_card)

        expect(data[:modal]).to eq("shared_popover")
        expect(data[:popover_frame_id]).to eq("stripe_card_#{stripe_card.public_id}")
      end
    end
  end
end
