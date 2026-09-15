# frozen_string_literal: true

require "rails_helper"

# Rails otherwise falls back to any registered template format when the
# requested extension is unknown, so a backup-file probe like `/feed.atom~`
# rendered the real feed with a 200 and the PCI scan flagged it.
RSpec.describe "Unknown format extensions", type: :request do
  let(:event) { create(:event, is_public: true) }

  it "returns 404 instead of rendering the page" do
    get "/#{event.slug}/feed.atom~"
    expect(response).to have_http_status(:not_found)

    get "/#{event.slug}.html~"
    expect(response).to have_http_status(:not_found)
  end

  it "still serves known formats and extension-less routes" do
    get "/#{event.slug}/feed.atom"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/atom+xml")

    get "/#{event.slug}/feed"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/atom+xml")
  end
end
