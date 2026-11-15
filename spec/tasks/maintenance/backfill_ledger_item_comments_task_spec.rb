# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillLedgerItemCommentsTask, versioning: true do
  let(:item) { create(:ledger_item) }
  let(:hcb_code) { create(:hcb_code, ledger_item: item) }

  def legacy_comment(commentable, **attributes)
    create(:comment, :legacy_on_hcb_code, commentable:, **attributes)
  end

  describe "#collection" do
    it "is the HCB codes with a ledger item and comments, including soft-deleted ones" do
      with_comment = hcb_code
      legacy_comment(with_comment)
      with_deleted_comment = create(:hcb_code, ledger_item: create(:ledger_item))
      legacy_comment(with_deleted_comment).destroy!
      without_item = create(:hcb_code)
      legacy_comment(without_item)
      create(:hcb_code, ledger_item: create(:ledger_item))

      expect(described_class.new.collection).to contain_exactly(with_comment, with_deleted_comment)
    end
  end

  describe "#process" do
    it "moves the code's comments onto its ledger item, keeping their timestamps" do
      comment = legacy_comment(hcb_code, created_at: 3.days.ago)
      deleted = legacy_comment(hcb_code)
      deleted.destroy!

      described_class.new.process(hcb_code)

      expect(comment.reload.commentable).to eq(item)
      expect(comment.created_at).to be_within(1.second).of(3.days.ago)
      expect(Comment.with_deleted.find(deleted.id).commentable).to eq(item)
      expect(hcb_code.comments).to be_empty
    end

    it "doesn't record the move as an edit of the comment" do
      comment = legacy_comment(hcb_code)

      expect { described_class.new.process(hcb_code) }.not_to(change { comment.reload.versions.count })
      expect(comment).not_to be_edited
    end

    it "leaves the ledger item's cached counts as they were" do
      legacy_comment(hcb_code)
      legacy_comment(hcb_code, admin_only: true)
      item.refresh!

      expect { described_class.new.process(hcb_code) }.not_to(change { item.reload.slice(:comment_count, :not_admin_only_comment_count) })
      expect(item.comment_count).to eq(2)
    end

    it "is a no-op the second time" do
      legacy_comment(hcb_code)
      described_class.new.process(hcb_code)

      expect { described_class.new.process(hcb_code) }.not_to(change { item.comments.pluck(:id, :updated_at) })
    end
  end
end
