# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::TransactionsController do
  let(:user) { create(:user) }
  let(:event) { create(:event) }

  def authenticate(as_user)
    trusted_app = Doorkeeper::Application.create!(name: "Trusted App", redirect_uri: "https://hcb.hackclub.com", trusted: true)
    token = create(:api_token, user: as_user, application: trusted_app)
    request.headers["Authorization"] = "Bearer #{token.token}"
  end

  def transaction_belonging_to(an_event)
    ct = create(:canonical_transaction)
    create(:canonical_event_mapping, canonical_transaction: ct, event: an_event)
    ct.local_hcb_code
  end

  describe "PATCH #update with tag_ids" do
    let(:tag) { event.tags.create!(label: "Snacks", emoji: "🍕", color: "muted") }

    before do
      create(:organizer_position, user:, event:, role: :member)
      authenticate(user)
    end

    it "applies the tags to the transaction's ledger item" do
      hcb_code = transaction_belonging_to(event)

      patch :update, params: { id: hcb_code.public_id, event_id: event.public_id, tag_ids: [tag.public_id] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(hcb_code.reload.ledger_item.tags).to include(tag)
    end

    it "refuses to attach a tag from another organization" do
      other_event = create(:event)
      create(:organizer_position, user:, event: other_event, role: :member)
      hcb_code = transaction_belonging_to(other_event)

      patch :update, params: { id: hcb_code.public_id, event_id: event.public_id, tag_ids: [tag.public_id] }, as: :json

      expect(hcb_code.reload.ledger_item.tags).to be_empty
    end
  end
end
