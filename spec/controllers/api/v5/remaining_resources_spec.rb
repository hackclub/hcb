# frozen_string_literal: true

require "rails_helper"

# The resources with no v3 entity. All of them must stay closed to transparency
# viewers even on a transparent organization — that is the half of the rule
# that is easy to get wrong, because the organization itself is public.
RSpec.describe "v5 resources with no public tier" do
  render_views

  before do
    allow_any_instance_of(UsersHelper).to receive(:profile_picture_for).and_return("https://gravatar.com/avatar/stubbed")
  end

  let(:transparent) { create(:event, :with_positive_balance, is_public: true) }

  def authenticate_as(user)
    request.headers["Authorization"] = "Bearer #{create(:api_token, user:).token}"
  end

  describe Api::V5::CardGrantsController, type: :controller do
    it "lists nothing to an anonymous caller on a transparent organization" do
      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to be_empty
    end

    it "lists nothing to an unrelated signed-in user" do
      authenticate_as(create(:user))

      get :index, params: {}, as: :json

      expect(response.parsed_body["data"]).to be_empty
    end
  end

  describe Api::V5::OrganizerPositionInvitesController, type: :controller do
    it "lists nothing to an anonymous caller" do
      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to be_empty
    end

    it "shows an organizer the invitations for their organization" do
      user = create(:user)
      # The organizer_position factory creates an invitation of its own, so
      # assert on the one under test rather than on a count.
      create(:organizer_position, user:, event: transparent, role: :manager)
      invitation = create(:organizer_position_invite, event: transparent)
      authenticate_as(user)

      get :index, params: {}, as: :json

      expect(response.parsed_body["data"].map { |i| i["id"] }).to include(invitation.public_id)
    end
  end

  describe Api::V5::ReceiptsController, type: :controller do
    it "refuses the receipt bin to an anonymous caller" do
      get :index, params: {}, as: :json

      expect(response.parsed_body["data"]).to be_empty
    end
  end

  describe Api::V5::StripeCardsController, type: :controller do
    # Cards are the exception among these: v3 publishes a transparent
    # organization's cards, so the index is not empty for an anonymous caller.
    it "lists a transparent organization's cards anonymously" do
      create(:stripe_card, :with_stripe_id, event: transparent)

      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(1)
    end

    it "withholds the card number digits from an anonymous caller" do
      create(:stripe_card, :with_stripe_id, event: transparent)

      get :index, params: {}, as: :json

      expect(response.parsed_body["data"].first).not_to include("last4", "exp_month", "exp_year")
    end
  end

end
