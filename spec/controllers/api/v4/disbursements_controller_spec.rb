# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::DisbursementsController do
  render_views

  describe "#create" do
    let(:user) { create(:user) }
    let(:source_event) { create(:event, :with_positive_balance) }
    let(:destination_event) { create(:event) }

    before do
      create(:organizer_position, user:, event: source_event)
      create(:organizer_position, user:, event: destination_event)

      token = create(:api_token, user:)
      request.headers["Authorization"] = "Bearer #{token.token}"
    end

    def post_create(key: "order-1234", **overrides)
      request.headers["Idempotency-Key"] = key
      post(:create, params: { event_id: source_event.friendly_id, to_organization_id: destination_event.public_id, name: "Boba Drops", amount_cents: 600_00, **overrides }, as: :json)
    end

    it "creates a disbursement" do
      post_create

      expect(response).to have_http_status(:created)
      expect(response.headers["Idempotent-Replayed"]).to be_nil
      disbursement = Disbursement.where(source_event:).sole
      expect(disbursement.idempotency_key).to eq("order-1234")
      expect(response.parsed_body["id"]).to eq(disbursement.public_id)
      expect(response.parsed_body["amount_cents"]).to eq(600_00)
    end

    it "replays the existing disbursement with a 201 and Idempotent-Replayed" do
      post_create
      disbursement = Disbursement.where(source_event:).sole

      post_create

      expect(response).to have_http_status(:created)
      expect(response.headers["Idempotent-Replayed"]).to eq("true")
      expect(response.parsed_body["id"]).to eq(disbursement.public_id)
      expect(Disbursement.where(source_event:).count).to eq(1)
    end

    it "returns 422 when the key is reused with a different payload" do
      post_create
      post_create(amount_cents: 1_00)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("error" => "idempotency_key_mismatch", "messages" => ["Idempotency-Key was already used with different parameters (amount)"])
      expect(Disbursement.where(source_event:).count).to eq(1)
    end

    it "rejects keys longer than 255 characters" do
      post_create(key: "k" * 256)

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("error" => "invalid_record", "messages" => ["Idempotency key is too long (maximum is 255 characters)"])
      expect(Disbursement.where(source_event:)).to be_empty
    end

    it "creates separate disbursements without a key" do
      post_create(key: nil, amount_cents: 1_00)
      post_create(key: nil, amount_cents: 1_00)

      expect(Disbursement.where(source_event:).count).to eq(2)
    end
  end
end
