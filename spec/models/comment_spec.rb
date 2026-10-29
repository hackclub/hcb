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

  describe "#save" do
    def attach_file(name)
      comment.file.attach(io: File.open(Rails.root.join("spec/fixtures/files/#{name}")), filename: name, content_type: "text/plain")
      comment.save
    end

    it "is flagged as edited when only the attached file changes" do
      expect(comment.edited?).to be false

      attach_file("attachment1.txt")

      expect(comment.reload.edited?).to be true
    end

    it "records the file change in the edit history" do
      attach_file("attachment1.txt")

      # the same condition the edit history renders "changed the attached file" on
      expect(comment.reload.versions.where(event: "update")).to include(
        have_attributes(changeset: hash_including("file"))
      )
    end

    it "does not create an extra version when nothing changes" do
      expect(comment.versions.size).to eq(1)
      comment.save
      expect(comment.versions.size).to eq(1)
    end
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
