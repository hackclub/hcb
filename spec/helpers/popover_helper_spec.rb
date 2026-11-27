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

  describe "#ledger_item_popover_data" do
    let(:event) { create(:event) }
    let(:item) { create(:ledger_item) }
    let(:user) { create(:user) }

    before do
      create(:ledger_mapping, :on_primary, ledger: event.ledger, ledger_item: item)

      # Helper specs don't run through a controller, so wire up Pundit's
      # `policy` the way ApplicationController does.
      current_user = user
      helper.extend(Pundit::Authorization)
      helper.singleton_class.define_method(:current_user) { current_user }
    end

    # Ledger::ItemsController#show serves the page to anyone the policy
    # allows, so the popover has to agree with the page or a member gets the
    # HCB code popover from a row and the ledger item page from its link.
    it "opens the ledger item for a member who can view its page" do
      create(:organizer_position, event:, user:, role: :member)

      data = helper.ledger_item_popover_data(item)

      expect(data[:modal]).to eq("shared_popover")
      expect(data[:popover_src]).to eq(item.popover_path)
      expect(data[:popover_frame_id]).to eq(item.public_id)
      expect(data[:popover_state_url]).to eq(ledger_item_path(item))
    end

    it "falls back to the HCB code popover for a user who can't view the page" do
      hcb_code = create(:hcb_code, ledger_item: item)

      data = helper.ledger_item_popover_data(item)

      expect(data[:popover_src]).to eq(hcb_code.popover_path)
      expect(data[:popover_frame_id]).to eq(hcb_code.public_id)
    end
  end
end
