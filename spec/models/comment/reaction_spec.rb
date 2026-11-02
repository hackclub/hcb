# frozen_string_literal: true

require "rails_helper"

RSpec.describe Comment::Reaction, type: :model do
  let(:event) { create(:event) }
  let(:comment) { create(:comment, commentable: event) }
  let(:reactor) { create(:user) }

  describe "emoji uniqueness" do
    it "rejects a duplicate reaction from the same user" do
      described_class.create!(comment:, reactor:, emoji: "👍")

      duplicate = described_class.new(comment:, reactor:, emoji: "👍")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:emoji]).to include("has already been used for this comment")
    end

    it "allows re-reacting after the reaction was soft-deleted" do
      described_class.create!(comment:, reactor:, emoji: "👍").destroy!

      expect(described_class.new(comment:, reactor:, emoji: "👍")).to be_valid
    end

    it "allows the same emoji from a different user" do
      described_class.create!(comment:, reactor:, emoji: "👍")

      expect(described_class.new(comment:, reactor: create(:user), emoji: "👍")).to be_valid
    end
  end
end
