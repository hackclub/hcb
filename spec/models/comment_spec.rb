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
