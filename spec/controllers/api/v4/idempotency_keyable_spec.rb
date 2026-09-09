# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::IdempotencyKeyable do
  controller(Api::V4::ApplicationController) do
    def create
      skip_authorization

      raise Errors::IdempotencyKeyMismatch, "Idempotency-Key was already used with different parameters" if params[:mismatch]

      idempotent_replay! if params[:replay]

      render json: { key: idempotency_key }, status: :created
    end
  end

  before do
    token = create(:api_token, user: create(:user))
    request.headers["Authorization"] = "Bearer #{token.token}"
  end

  it "exposes the Idempotency-Key header to the action" do
    request.headers["Idempotency-Key"] = "order-1234"
    post(:create, as: :json)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to eq("key" => "order-1234")
    expect(response.headers["Idempotent-Replayed"]).to be_nil
  end

  it "treats a missing or blank header as no key" do
    request.headers["Idempotency-Key"] = "   "
    post(:create, as: :json)

    expect(response.parsed_body).to eq("key" => nil)
  end

  it "strips surrounding whitespace" do
    request.headers["Idempotency-Key"] = " order-1234 "
    post(:create, as: :json)

    expect(response.parsed_body).to eq("key" => "order-1234")
  end

  it "rejects invalid UTF-8 with a 400" do
    request.headers["Idempotency-Key"] = "caf\xE9".b
    post(:create, as: :json)

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body).to eq("error" => "invalid_operation", "messages" => ["Idempotency-Key must be valid UTF-8"])
  end

  it "marks replayed responses with the Idempotent-Replayed header and keeps the original status" do
    request.headers["Idempotency-Key"] = "order-1234"
    post(:create, params: { replay: true }, as: :json)

    expect(response).to have_http_status(:created)
    expect(response.headers["Idempotent-Replayed"]).to eq("true")
  end

  it "renders a key/payload mismatch as a 422" do
    request.headers["Idempotency-Key"] = "order-1234"
    post(:create, params: { mismatch: true }, as: :json)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq("error" => "idempotency_key_mismatch", "messages" => ["Idempotency-Key was already used with different parameters"])
  end
end
