# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cache-Control: no-transform", type: :request do
  let(:event) { create(:event, is_public: true) }

  it "is set on HTML so the reverse proxy does not gzip it (BREACH)" do
    get auth_users_path

    expect(response.media_type).to eq("text/html")
    expect(response.headers["cache-control"]).to include("no-transform")
  end

  it "is not set on non-HTML responses" do
    get "/#{event.slug}/feed.atom"

    expect(response.headers["cache-control"]).not_to include("no-transform")
  end
end
