# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Static pages", type: :request do
  describe "GET /" do
    it "hides organizations the user is locked out of for not enabling two-factor authentication" do
      user = create(:user)
      locked_out = create(:organizer_position, user:, event: create(:event, name: "Locked Out Org")).event
      create(:organizer_position, user:, event: create(:event, name: "Open Org"))
      require_two_factor_authentication!(locked_out, at: 8.days.ago)
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(create(:user_session, user:, expiration_at: 1.hour.from_now))

      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("href=\"/#{Event.find_by(name: "Open Org").slug}\"")
      expect(response.body).not_to include("href=\"/#{locked_out.slug}\"")
      # The banner still names it, so the member knows why it's missing.
      expect(response.body).to include("You don't have access to Locked Out Org")
    end

    it "shows one banner for every organization requiring two-factor authentication" do
      user = create(:user)
      parent = create(:event, name: "Parent Org")
      create(:organizer_position, user:, event: create(:event, name: "Child Org", parent:))
      create(:organizer_position, user:, event: create(:event, name: "Other Org"))
      create(:organizer_position, user:, event: create(:event, name: "Later Org"))
      require_two_factor_authentication!(parent, at: 8.days.ago)
      require_two_factor_authentication!(Event.find_by(name: "Other Org"), at: 9.days.ago)
      require_two_factor_authentication!(Event.find_by(name: "Later Org"), at: 1.day.ago)
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(create(:user_session, user:, expiration_at: 1.hour.from_now))

      get "/"

      expect(response.body.scan("transparency-banner").size).to eq(1)
      expect(response.body).to include("You don't have access to Parent Org and Other Org until you")
      expect(response.body).to include("Later Org requires it too, from <time")
    end
  end

  describe "GET /branding" do
    it "emits an absolute Open Graph image URL for social previews" do
      get branding_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('meta property="og:image" content="https://hcb.hackclub.com/brand/hcb-icon-icon-original.png"')
    end
  end
end
