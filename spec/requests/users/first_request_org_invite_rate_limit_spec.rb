# frozen_string_literal: true

require "rails_helper"

# Rack::Attack is `enabled = Rails.env.production?` (see
# config/initializers/rack_attack.rb), so we can't exercise the throttle in
# specs the way we would normally. Mirror the registration-style assertion
# used elsewhere in this repo (see first_verify_email_authz_spec.rb): read
# the rack_attack source and assert the throttle rule is present.
RSpec.describe "POST /first/request_org_invite rate-limit registration" do
  let(:source) { File.read(Rails.root.join("config/initializers/rack_attack.rb")) }

  it "is covered by a Rack::Attack throttle scoped to /first/request_org_invite" do
    expect(source).to match(/throttle\([^)]*request_org_invite[^)]*\)/),
                      "Expected a `throttle(...)` rule whose name references `request_org_invite` " \
                      "to be registered in config/initializers/rack_attack.rb. Without it, a " \
                      "signed-in user can spam OrganizerPositionInvite::Request rows (and the " \
                      "manager notification emails they trigger) by hammering the endpoint."
  end

  it "limits the throttle to 2 requests per day" do
    block = source[/throttle\("first\/request_org_invite\/user".*?\bend\b/m]

    expect(block).to be_present, "Could not locate the request_org_invite throttle block in rack_attack.rb"
    expect(block).to include("limit: 2"),
                     "The product spec calls for twice-per-day per-user. Found block:\n#{block}"
    expect(block).to include("period: 1.day"),
                     "The product spec calls for twice-per-day per-user. Found block:\n#{block}"
  end

  it "keys the throttle on the signed-in user's session, not just the request IP" do
    block = source[/throttle\("first\/request_org_invite\/user".*?\bend\b/m]

    expect(block).to be_present, "Could not locate the request_org_invite throttle block in rack_attack.rb"
    expect(block).to include('req.cookies["session_token"]'),
                     "Per-user limit is meaningless if the throttle key is `req.ip`: an attacker on " \
                     "a NAT'd network would knock real users out, and a single attacker rotating IPs " \
                     "would bypass the cap. Use the session_token cookie as the per-user proxy."
  end
end
