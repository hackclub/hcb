# frozen_string_literal: true

require "rails_helper"

# Write actions are authorized by `create?`/`update?`/`destroy?` on the record,
# not by the field lists — but their *responses* still render through the v5
# serializers, so the tiers apply on the way back out.
RSpec.describe "v5 write actions" do
  render_views

  before do
    allow_any_instance_of(UsersHelper).to receive(:profile_picture_for).and_return("https://gravatar.com/avatar/stubbed")
  end

  let(:event) { create(:event, :with_positive_balance, is_public: true) }

  def authenticate_as(user)
    request.headers["Authorization"] = "Bearer #{create(:api_token, user:).token}"
  end

  def member_of(event, role: :member)
    create(:user).tap { |u| create(:organizer_position, user: u, event:, role:) }
  end

  def ledger_item_for(event, memo: "Test item")
    item = create(:ledger_item)
    ::Ledger::Mapping.create!(ledger: event.ledger, ledger_item: item, on_primary_ledger: true)
    item.update_columns(amount_cents: -1000, memo:, status: "settled")
    item.reload
  end

  describe Api::V5::TagsController, type: :controller do
    it "creates a tag for a member" do
      authenticate_as(member_of(event))

      post :create, params: { organization_id: event.public_id, label: "Travel", color: "red", emoji: "🧳" }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("label" => "Travel")
    end

    it "refuses tag creation to an anonymous caller on a transparent organization" do
      post :create, params: { organization_id: event.public_id, label: "Travel", emoji: "🧳" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    # `permitted_attributes` is the write list; it must not accept a field that
    # merely happens to exist on the record.
    it "ignores unpermitted attributes" do
      authenticate_as(member_of(event))

      post :create, params: { organization_id: event.public_id, label: "Travel", color: "red", emoji: "🧳", event_id: 999_999 }, as: :json

      expect(response).to have_http_status(:created)
      expect(Tag.find_by_public_id(response.parsed_body["id"]).event_id).to eq(event.id)
    end
  end

  describe Api::V5::TransactionsController, type: :controller do
    it "updates a memo for a member" do
      item = ledger_item_for(event)
      authenticate_as(member_of(event))

      patch :update, params: { id: item.public_id, memo: "Renamed" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(item.reload.custom_memo).to eq("Renamed")
    end

    it "refuses a memo update from a reader" do
      item = ledger_item_for(event)
      authenticate_as(member_of(event, role: :reader))

      patch :update, params: { id: item.public_id, memo: "Renamed" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "refuses a memo update from an anonymous caller" do
      item = ledger_item_for(event)

      patch :update, params: { id: item.public_id, memo: "Renamed" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

end
