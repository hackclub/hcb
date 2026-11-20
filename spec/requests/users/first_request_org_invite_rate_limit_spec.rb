# frozen_string_literal: true

require "rails_helper"

# Rack::Attack is only enabled in production (see config/initializers/rack_attack.rb),
# so exercise the throttle's rule directly rather than through the middleware.
RSpec.describe "POST /first/request_org_invite rate limit" do
  let(:throttle) { Rack::Attack.throttles.fetch("first/request_org_invite/user") }

  def request_for(path:, method:, session_token: nil)
    env = Rack::MockRequest.env_for(path, method:)
    env["HTTP_COOKIE"] = "session_token=#{session_token}" if session_token
    Rack::Attack::Request.new(env)
  end

  # Each request creates an OrganizerPositionInvite::Request and emails the
  # event's managers, so a signed-in user could spam them without this.
  it "allows two requests per day" do
    expect(throttle.limit).to eq(2)
    expect(throttle.period).to eq(1.day)
  end

  # Keyed on the request IP, a NAT'd network would knock real users out and an
  # attacker rotating IPs would bypass the cap.
  it "keys the throttle on the signed-in user's session" do
    expect(throttle.block.call(request_for(path: "/first/request_org_invite", method: "POST", session_token: "abc"))).to eq("abc")
  end

  it "leaves other requests alone" do
    expect(throttle.block.call(request_for(path: "/first/request_org_invite", method: "GET", session_token: "abc"))).to be_nil
    expect(throttle.block.call(request_for(path: "/first", method: "POST", session_token: "abc"))).to be_nil
    expect(throttle.block.call(request_for(path: "/first/request_org_invite", method: "POST"))).to be_nil
  end
end
