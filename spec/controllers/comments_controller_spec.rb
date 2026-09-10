# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentsController do
  include SessionSupport

  describe "POST #create" do
    let(:user) { create(:user, verified: true) }
    let(:report) { create(:reimbursement_report, user:) }
    let(:frame_url) { "http://test.host/reimbursements/reports/#{report.id}?frame=true" }

    before do
      create_session(user, verified: true)
      request.env["HTTP_REFERER"] = "http://test.host/my/inbox"
    end

    def create_comment
      post :create, params: {
        reimbursement_report_id: report.id,
        comment: {
          content: "Hi!",
          commentable_type: "Reimbursement::Report",
          commentable_id: report.id,
          return_to: frame_url
        }
      }
    end

    it "reloads the frame and streams the flash into the popover when submitted from within a turbo frame" do
      request.headers["Turbo-Frame"] = "reimbursement_report_#{report.id}"

      expect { create_comment }.to change { report.comments.count }.by(1)
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(response.body).to include("shared_popover_flash")
      expect(response.body).to include("Comment created.")
      expect(response.body).to include("src=\"#{frame_url}\"")
    end

    it "ignores an external return_to and reloads the commentable instead" do
      request.headers["Turbo-Frame"] = "reimbursement_report_#{report.id}"

      post :create, params: {
        reimbursement_report_id: report.id,
        comment: {
          content: "Hi!",
          commentable_type: "Reimbursement::Report",
          commentable_id: report.id,
          return_to: "https://evil.example.com"
        }
      }

      expect(response.body).not_to include("evil.example.com")
      expect(response.body).to include("src=\"#{reimbursement_report_path(report)}\"")
    end

    it "redirects back to the referring page otherwise" do
      expect { create_comment }.to change { report.comments.count }.by(1)
      expect(response).to redirect_to("http://test.host/my/inbox")
    end
  end

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
end
