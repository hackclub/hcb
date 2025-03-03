# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChangelogPost, type: :model do
  let(:changelog_post) { create(:changelog_post) }
  let(:user) { create(:user) }

  describe "latest" do
    it "returns the most recently published changelog post" do
      changelog_post = create(:changelog_post, published_at: 1.day.ago)
      latest_changelog_post = create(:changelog_post, published_at: Time.current)
      expect(ChangelogPost.latest).to eq(latest_changelog_post)
    end
  end

  describe "mark_viewed_by!" do
    it "adds a user to the viewers association" do
      expect(changelog_post.viewers).to be_empty
      changelog_post.mark_viewed_by!(user)
      expect(changelog_post.viewers).to include(user)
    end

    it "skips adding a user to the viewers association if they are already there" do
      changelog_post.mark_viewed_by!(user)
      changelog_post.mark_viewed_by!(user)
      expect(changelog_post.viewers.size).to eq(1)
    end

  end

  describe "viewed_by?" do
    it "returns false when a user hasn't seen a changelog post" do
      expect(changelog_post.viewed_by?(user)).to eq(false)
    end

    it "returns true when a user has seen a changelog post" do
      changelog_post.mark_viewed_by!(user)
      expect(changelog_post.viewed_by?(user)).to eq(true)
    end
  end

end
