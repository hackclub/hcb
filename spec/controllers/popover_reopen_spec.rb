# frozen_string_literal: true

require "rails_helper"

# Popovers push their own URL into the browser's history, so reloading a page
# with an open popover lands the user on that URL instead of the page it was
# opened from. ApplicationController#reopen_popover sends the user back there
# with a #popover fragment, which tells the front-end to reopen it (see ui.js).
RSpec.describe MyController do
  let(:state_url) { "http://test.host/my/cards" }
  let(:return_url) { "http://test.host/my/inbox" }

  def sign_in
    user = create(:user)
    user_session = User::Session.create!(
      user:,
      verified: true,
      session_token: SecureRandom.urlsafe_base64,
      expiration_at: 7.days.from_now,
    )
    cookies.encrypted[:session_token] = {
      value: user_session.session_token,
      expires: User::Session::MAX_SESSION_DURATION.from_now,
      httponly: true,
    }
  end

  def open_popover_cookie(state_url: self.state_url, return_url: self.return_url)
    {
      stateUrl: state_url,
      returnUrl: return_url,
      trigger: { popoverTitle: "A transaction" }
    }.to_json
  end

  before do
    sign_in
    request.headers["Sec-Fetch-Dest"] = "document" # a real browser navigation
    request.cookies["hcb_open_popover"] = open_popover_cookie
  end

  it "redirects a reload of the popover's URL back to the page it was opened from" do
    get :cards

    expect(response).to redirect_to("#{return_url}#popover")
  end

  it "leaves Turbo visits and other fetches alone" do
    request.headers["Sec-Fetch-Dest"] = "empty"

    get :cards

    expect(response).to have_http_status(:ok)
  end

  it "ignores a cookie belonging to a different page" do
    request.cookies["hcb_open_popover"] = open_popover_cookie(state_url: "http://test.host/my/receipts")

    get :cards

    expect(response).to have_http_status(:ok)
  end

  it "refuses to redirect off-site" do
    request.cookies["hcb_open_popover"] = open_popover_cookie(return_url: "https://evil.example.org/")

    get :cards

    expect(response).to have_http_status(:ok)
  end

  it "ignores a malformed cookie" do
    request.cookies["hcb_open_popover"] = "not json"

    get :cards

    expect(response).to have_http_status(:ok)
  end
end
