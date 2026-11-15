# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /taxbandits/w9_certificate.pdf", type: :request do
  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  let(:pdf) { "%PDF-1.4\nsigned W-9\n%%EOF".b }
  let(:token) { Tax::W9PdfStore.store(pdf) }

  def get_pdf(with: token)
    get "/taxbandits/w9_certificate.pdf", params: { token: with }
  end

  it "serves the staged PDF" do
    get_pdf

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
    expect(response.body.b).to eq(pdf)
  end

  it "tells every cache along the way not to keep a copy" do
    get_pdf

    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  # TaxBandits fetches this from infrastructure whose addresses they don't
  # publish, so neither the webhook IP allowlist nor the webhook HMAC can apply
  # here. The endpoint has to be reachable without either.
  it "does not require the webhook's IP or signature" do
    get_pdf

    expect(response).to have_http_status(:ok)
  end

  it "still serves a retry inside the grace period" do
    get_pdf
    get_pdf

    expect(response).to have_http_status(:ok)
    expect(response.body.b).to eq(pdf)
  end

  it "stops serving once the grace period is over" do
    get_pdf

    travel(Tax::W9PdfStore::GRACE_PERIOD + 1.second) do
      get_pdf
      expect(response).to have_http_status(:not_found)
    end
  end

  it "stops serving an unfetched PDF once its TTL is up" do
    token # stage it now, not inside the travelled window

    travel(Tax::W9PdfStore::UNFETCHED_TTL + 1.minute) do
      get_pdf
      expect(response).to have_http_status(:not_found)
    end
  end

  it "404s for a token it never issued" do
    get_pdf(with: SecureRandom.urlsafe_base64(32))

    expect(response).to have_http_status(:not_found)
  end

  it "404s when no token is given" do
    get "/taxbandits/w9_certificate.pdf"

    expect(response).to have_http_status(:not_found)
  end

  it "keeps the token out of the request log" do
    expect(ActionDispatch::Request.new(Rails.application.env_config.merge(
                                         Rack::MockRequest.env_for("/taxbandits/w9_certificate.pdf?token=#{token}")
                                       )).filtered_path).to eq("/taxbandits/w9_certificate.pdf?token=[FILTERED]")
  end
end
