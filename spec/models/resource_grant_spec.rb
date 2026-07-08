# frozen_string_literal: true

require "rails_helper"

RSpec.describe ResourceGrant do
  def build_grant(owner, **overrides)
    described_class.new({ owner:, resource_type: "comments", access_level: "read" }.merge(overrides))
  end

  # Validations are owner-agnostic, so exercise them once per owner type
  # rather than duplicating the whole suite per model.
  [
    -> { create(:api_token) },
    -> { Doorkeeper::Application.create!(name: "Test App", redirect_uri: "https://example.com/callback", scopes: "restricted") },
  ].each do |owner_factory|
    context "owned by a #{owner_factory.call.class}" do
      let(:owner) { owner_factory.call }

      it "is valid with only a scope root" do
        expect(build_grant(owner, scope_root_type: "Event", scope_root_id: 1)).to be_valid
      end

      it "is valid with no scope root (whole resource type)" do
        expect(build_grant(owner)).to be_valid
      end

      it "is invalid when scope_root_type is set without scope_root_id" do
        expect(build_grant(owner, scope_root_type: "Event")).not_to be_valid
      end

      it "is invalid when scope_root_id is set without scope_root_type" do
        expect(build_grant(owner, scope_root_id: 1)).not_to be_valid
      end

      it "rejects a scope_root_type outside the allowed list" do
        expect(build_grant(owner, scope_root_type: "Comment", scope_root_id: 1)).not_to be_valid
      end

      it "requires resource_type" do
        expect(build_grant(owner, resource_type: nil)).not_to be_valid
      end

      it "rejects an access_level outside read/write" do
        expect(build_grant(owner, access_level: "admin")).not_to be_valid
      end

      it "is destroyed when its owner is destroyed" do
        grant = described_class.create!(owner:, resource_type: "comments", access_level: "read")
        owner.destroy!
        expect(described_class.exists?(grant.id)).to be(false)
      end
    end
  end
end
