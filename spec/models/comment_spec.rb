# frozen_string_literal: true

require "rails_helper"

RSpec.describe Comment, type: :model, versioning: true do
  let(:event) { create(:event) }
  let(:comment) { create(:comment, commentable: event) }

  it "is valid" do
    expect(comment).to be_valid
  end

  it "uses PaperTrail versioning in tests" do
    expect(described_class.new).to be_versioned
    expect(comment).to be_versioned
  end

  it "is versioned by PaperTrail on edit" do
    expect(comment.versions.size).to eq(1)
    comment.update(content: "Edited content")
    expect(comment.versions.size).to eq(2)
  end

  describe "#shared?" do
    it "returns true when commentable is a Disbursement" do
      disbursement = create(:disbursement)
      comment = create(:comment, commentable: disbursement)

      expect(comment.shared?).to be true
    end

    it "returns false when commentable is an HcbCode" do
      hcb_code = create(:hcb_code)
      comment = create(:comment, commentable: hcb_code)

      expect(comment.shared?).to be false
    end

    it "returns false when commentable is an Event" do
      comment = create(:comment, commentable: event)

      expect(comment.shared?).to be false
    end
  end

  describe "#tracked_event_id" do
    it "returns nil for admin_only comments" do
      hcb_code = create(:hcb_code)
      hcb_code.update_columns(event_id: event.id)
      comment = create(:comment, commentable: hcb_code, admin_only: true)

      expect(comment.tracked_event_id).to be_nil
    end

    it "returns the commentable's event id" do
      hcb_code = create(:hcb_code)
      hcb_code.update_columns(event_id: event.id)
      comment = create(:comment, commentable: hcb_code)

      expect(comment.tracked_event_id).to eq(event.id)
    end

    # Ledger::Item has no generic event/events method (it can be mapped onto
    # more than one ledger) — this goes through primary_ledger instead.
    it "returns the ledger item's primary ledger's event id for a Ledger::Item commentable" do
      item = Ledger::Item.new(amount_cents: 0, memo: "Test", datetime: Time.current)
      item.save(validate: false)
      create(:ledger_mapping, :on_primary, ledger: event.ledger, ledger_item: item)
      comment = create(:comment, commentable: item)

      expect(comment.tracked_event_id).to eq(event.id)
    end
  end

  context "when missing content" do
    before do
      comment.content = ""
    end

    it "is not valid" do
      expect(comment).not_to be_valid
    end

    context "has attachment" do
      before do
        comment.file.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/attachment1.txt")),
          filename: "attachment1.txt",
          content_type: "text/plain"
        )
      end

      it "is valid" do
        expect(comment).to be_valid
      end
    end
  end
end
