# frozen_string_literal: true

require "rails_helper"

RSpec.describe Announcement, type: :model do
  describe "content validation" do
    let(:announcement) { described_class.new(title: "Update", author: build(:user), event: build(:event)) }
    let(:block) { { "type" => "Announcement::Block::DonationGoal", "attrs" => { "id" => nil } } }

    it "rejects a block with a nil ID" do
      announcement.content = { "type" => "doc", "content" => [block] }

      expect(announcement).not_to be_valid
      expect(announcement.errors[:content]).to include("contains an announcement block without an ID")
    end

    it "rejects a nested block with no ID attribute" do
      block.delete("attrs")
      announcement.content = { "type" => "doc", "content" => [{ "type" => "blockquote", "content" => [block] }] }

      expect(announcement).not_to be_valid
      expect(announcement.errors[:content]).to include("contains an announcement block without an ID")
    end

    it "allows a block with an ID and a paragraph without one" do
      block["attrs"]["id"] = 123
      announcement.content = { "type" => "doc", "content" => [{ "type" => "paragraph" }, block] }

      expect(announcement).to be_valid
    end

    it "allows empty draft content" do
      announcement.content = {}

      expect(announcement).to be_valid
    end
  end
end
