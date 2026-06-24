# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketingHelper, type: :helper do
  describe "#funder_faqs" do
    # Guards the "related" cross-links: they reference stable ids (not question wording), so this
    # catches a typo'd or stale id before it silently drops a link on the page.
    it "has unique ids, and every 'related' reference points to an existing FAQ id" do
      entries = helper.funder_faqs(stats: nil).flat_map { |group| group[:faqs] }
      ids = entries.filter_map { |entry| entry[:id] }
      related = entries.flat_map { |entry| entry[:related] || [] }

      expect(ids).to eq(ids.uniq), "FAQ ids must be unique"
      expect(related - ids).to be_empty, "every related id must match an existing FAQ id"
    end
  end
end
