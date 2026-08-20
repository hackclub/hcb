# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillCommentCommentablesToLedgerItemTask do
  let(:user) { create(:user) }

  describe "#collection" do
    it "includes comments on an HcbCode with a ledger_item" do
      item = create(:ledger_item)
      hcb_code = create(:hcb_code, ledger_item: item)
      comment = create(:comment, commentable: hcb_code, user:)

      expect(described_class.new.collection).to include(comment)
    end

    it "excludes comments on an HcbCode with no ledger_item" do
      hcb_code = create(:hcb_code)
      comment = create(:comment, commentable: hcb_code, user:)

      expect(described_class.new.collection).not_to include(comment)
    end

    it "excludes comments already on a Ledger::Item" do
      item = create(:ledger_item)
      comment = create(:comment, commentable: item, user:)

      expect(described_class.new.collection).not_to include(comment)
    end

    it "includes soft-deleted comments" do
      item = create(:ledger_item)
      hcb_code = create(:hcb_code, ledger_item: item)
      comment = create(:comment, commentable: hcb_code, user:)
      comment.destroy

      expect(described_class.new.collection).to include(comment)
    end
  end

  describe "#process" do
    it "moves the comment to the HcbCode's ledger_item" do
      item = create(:ledger_item)
      hcb_code = create(:hcb_code, ledger_item: item)
      comment = create(:comment, commentable: hcb_code, user:)

      described_class.new.process(comment)

      expect(comment.reload.commentable).to eq(item)
    end

    it "refreshes the ledger item's cached comment counts as a side effect" do
      item = create(:ledger_item)
      hcb_code = create(:hcb_code, ledger_item: item)
      comment = create(:comment, commentable: hcb_code, user:)

      described_class.new.process(comment)

      expect(item.reload.comment_count).to eq(1)
      expect(item.not_admin_only_comment_count).to eq(1)
    end
  end
end
