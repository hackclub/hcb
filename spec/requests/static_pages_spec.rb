# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Static pages", type: :request do
  describe "GET /branding" do
    it "emits an absolute Open Graph image URL for social previews" do
      get branding_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('meta property="og:image" content="https://hcb.hackclub.com/brand/hcb-icon-icon-original.png"')
    end
  end
end
