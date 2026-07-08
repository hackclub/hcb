# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiToken, "object scoping" do
  let(:token) { create(:api_token) }
  let(:event) { create(:event) }
  let(:other_event) { create(:event) }
  # HcbCode's after_create callback (write_event_and_subledger_id) derives
  # event_id from canonical transaction mappings and overwrites whatever
  # was passed in at creation, so it has to be forced afterward here.
  let(:hcb_code) { create(:hcb_code).tap { |hc| hc.update_column(:event_id, event.id) } }
  let(:comment) { create(:comment, commentable: hcb_code) }

  describe "#has_grants_for?" do
    it "is false with no grants" do
      expect(token.has_grants_for?(:read, "comments")).to be(false)
    end

    it "is true once any grant exists for that type + level" do
      token.resource_grants.create!(resource_type: "comments", access_level: "read", scope_root_type: "Event", scope_root_id: event.id)
      expect(token.has_grants_for?(:read, "comments")).to be(true)
      expect(token.has_grants_for?(:write, "comments")).to be(false)
    end
  end

  describe "#permits_object?" do
    it "is unrestricted when there are no grants for the type" do
      expect(token.permits_object?(:read, "comments", comment)).to be(true)
    end

    it "allows a record covered by a matching scope-root grant" do
      token.resource_grants.create!(resource_type: "comments", access_level: "read", scope_root_type: "Event", scope_root_id: event.id)
      expect(token.permits_object?(:read, "comments", comment)).to be(true)
    end

    it "denies a record not covered by the token's scope-root grants" do
      token.resource_grants.create!(resource_type: "comments", access_level: "read", scope_root_type: "Event", scope_root_id: other_event.id)
      expect(token.permits_object?(:read, "comments", comment)).to be(false)
    end

    it "allows every record of the type when the grant has no scope root" do
      token.resource_grants.create!(resource_type: "comments", access_level: "read")
      expect(token.permits_object?(:read, "comments", comment)).to be(true)
    end

    it "leaves read unrestricted when only a write grant exists (levels are independent)" do
      token.resource_grants.create!(resource_type: "comments", access_level: "write", scope_root_type: "Event", scope_root_id: other_event.id)
      expect(token.permits_object?(:read, "comments", comment)).to be(true)
    end
  end
end
