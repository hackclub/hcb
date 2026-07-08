# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiToken::ResourceGrant do
  def build_grant(**overrides)
    token = create(:api_token)
    described_class.new({ api_token: token, resource_type: "comments", access_level: "read" }.merge(overrides))
  end

  it "is valid with only a scope root" do
    grant = build_grant(scope_root_type: "Event", scope_root_id: 1)
    expect(grant).to be_valid
  end

  it "is valid with no scope root (whole resource type)" do
    grant = build_grant
    expect(grant).to be_valid
  end

  it "is invalid when scope_root_type is set without scope_root_id" do
    grant = build_grant(scope_root_type: "Event")
    expect(grant).not_to be_valid
  end

  it "is invalid when scope_root_id is set without scope_root_type" do
    grant = build_grant(scope_root_id: 1)
    expect(grant).not_to be_valid
  end

  it "rejects a scope_root_type outside the allowed list" do
    grant = build_grant(scope_root_type: "Comment", scope_root_id: 1)
    expect(grant).not_to be_valid
  end

  it "requires resource_type" do
    grant = build_grant(resource_type: nil)
    expect(grant).not_to be_valid
  end

  it "rejects an access_level outside read/write" do
    grant = build_grant(access_level: "admin")
    expect(grant).not_to be_valid
  end
end
