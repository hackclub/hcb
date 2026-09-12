# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentsController do
  include SessionSupport

  context "models including Commentable" do
    it "are explicitly registered" do
      Rails.application.eager_load!

      ApplicationRecord.descendants
                       .filter { _1.include?(Commentable) }
                       .each do |klass|
        expect(CommentsController::COMMENTABLE_TYPE_MAP).to have_key(klass.to_s)
      end
    end
  end

  describe "#update", versioning: true do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let(:hcb_code) { create(:disbursement, source_event: event).outgoing_disbursement.local_hcb_code }
    let(:comment) { create(:comment, commentable: hcb_code, user:, content: "Original content") }

    before do
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)
    end

    it "allows attaching a new file to an existing comment" do
      patch :update, params: {
        id: comment.to_param,
        comment: {
          content: "Edited content",
          file: fixture_file_upload("attachment1.txt", "text/plain")
        }
      }

      expect(response).to have_http_status(:found)
      comment.reload
      expect(comment.content).to eq("Edited content")
      expect(comment.file).to be_attached
    end

    it "allows replacing an existing attached file" do
      comment.file.attach(io: File.open(Rails.root.join("spec/fixtures/files/attachment1.txt")), filename: "attachment1.txt", content_type: "text/plain")

      patch :update, params: {
        id: comment.to_param,
        comment: {
          content: comment.content,
          file: fixture_file_upload("attachment2.txt", "text/plain")
        }
      }

      expect(response).to have_http_status(:found)
      expect(comment.reload.file.filename.to_s).to eq("attachment2.txt")
    end

    it "marks the comment as edited when only the file changes" do
      expect(comment.edited?).to be false

      patch :update, params: {
        id: comment.to_param,
        comment: {
          content: comment.content,
          file: fixture_file_upload("attachment1.txt", "text/plain")
        }
      }

      expect(response).to have_http_status(:found)
      expect(comment.reload.edited?).to be true
    end
  end
end
