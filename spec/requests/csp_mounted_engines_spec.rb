# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CSP on the mounted admin engines", type: :request do
  before do
    allow(TurnstileService).to receive_messages(site_key: "0x0000site", secret_key: "0x0000secret")
  end

  # Falls back to the enforced header so these survive flipping CSP_ENFORCE.
  def policy
    response.headers["Content-Security-Policy-Report-Only"] ||
      response.headers["Content-Security-Policy"]
  end

  # These paths 404 without an admin session; the middleware runs either way,
  # which is what's under test here.
  OptOutCspForMountedEngines::MOUNTED_PATHS.each do |path|
    it "serves #{path} without a policy, since its markup can't be nonced" do
      get path

      expect(policy).to be_nil
    end
  end

  it "still sends the policy everywhere else" do
    get root_path

    expect(policy).to be_present
  end

  # A bare `start_with?` would hand an exemption to any path that merely shares
  # a prefix, which is a route anyone can reach.
  it "does not exempt a path that only looks like an engine's" do
    OptOutCspForMountedEngines::MOUNTED_PATHS.each do |path|
      get "#{path}-not-really"

      expect(policy).to be_present, "#{path}-not-really was exempted"
    end
  end
end
