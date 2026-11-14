# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::StripeCardsController do
  render_views

  describe "#show" do
    # Card grant holders can see their own card, but they aren't members of the
    # organization that issued it. The card embeds that organization, and
    # `expand` used to let them read its finances through it.
    let(:transparent) { false }
    let(:event) { create(:event, is_public: transparent, plan_type: Event::Plan::HackClubAffiliate) }
    let(:grant_holder) { create(:user) }
    let(:stripe_card) do
      create(:stripe_card, :with_stripe_id, event:, stripe_cardholder: create(:stripe_cardholder, user: grant_holder))
    end

    let(:finance_keys) { %w[balance_cents fee_balance_cents total_spent_cents total_raised_cents] }

    before do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
      create(:card_grant_setting, event:)
      create(:card_grant, event:, user: grant_holder, stripe_card:)

      # `profile_picture_for` falls back to a Gravatar URL derived from the user's ID.
      allow_any_instance_of(UsersHelper).to receive(:gravatar_url).and_return("https://gravatar.com/avatar/stubbed")
    end

    def show_card_as(user)
      token = create(:api_token, user:)
      request.headers["Authorization"] = "Bearer #{token.token}"
      get(:show, params: { id: stripe_card.public_id, expand: "balance_cents,reporting" }, as: :json)
      expect(response).to have_http_status(:ok)
      response.parsed_body["organization"]
    end

    it "hides a private organization's finances from a card grant holder" do
      organization = show_card_as(grant_holder)

      expect(organization).to include("id" => event.public_id, "name" => event.name)
      expect(organization.keys).not_to include(*finance_keys)
    end

    it "shows them to the organization's readers" do
      reader = create(:user)
      create(:organizer_position, user: reader, event:, role: :reader)

      expect(show_card_as(reader).keys).to include(*finance_keys)
    end

    context "when the organization is transparent" do
      let(:transparent) { true }

      it "shows them to a card grant holder, as the web does" do
        expect(show_card_as(grant_holder).keys).to include(*finance_keys)
      end
    end
  end
end
