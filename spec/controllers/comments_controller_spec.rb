# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentsController do
  render_views

  include SessionSupport

  describe "POST #create" do
    let(:user) { create(:user, verified: true) }
    let(:report) { create(:reimbursement_report, user:) }
    let(:frame_url) { "http://test.host/reimbursements/reports/#{report.id}?frame=true" }

    before { create_session(user, verified: true) }

    def create_comment(content: "Hi!", return_to: frame_url)
      post :create, params: {
        reimbursement_report_id: report.id,
        comment: {
          content:,
          commentable_type: "Reimbursement::Report",
          commentable_id: report.id,
          return_to:
        }
      }
    end

    it "returns to the frame it was submitted from, keeping the flash for the response Turbo lands on" do
      request.headers["Turbo-Frame"] = "reimbursement_report_#{report.id}"

      expect { create_comment }.to change { report.comments.count }.by(1)
      expect(response).to redirect_to(frame_url)
      expect(response.headers["X-Flash"]).to be_nil
      expect(flash[:success]).to eq("Comment created.")
    end

    it "ignores an external return_to and falls back to the commentable" do
      expect { create_comment(return_to: "https://evil.example.com") }.to change { report.comments.count }.by(1)
      expect(response).to redirect_to(reimbursement_report_path(report))
    end

    it "flashes the errors of an invalid comment submitted from a frame, whose form is discarded" do
      request.headers["Turbo-Frame"] = "reimbursement_report_#{report.id}"

      expect { create_comment(content: "") }.not_to(change { report.comments.count })

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to eq("Content can't be blank")
      expect(CGI.unescape(response.headers["X-Flash"])).to include("Content can&#39;t be blank")
    end

    it "renders the form errors, without a flash, outside of a frame" do
      expect { create_comment(content: "") }.not_to(change { report.comments.count })

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to be_nil
      expect(response.headers["X-Flash"]).to be_nil
      expect(response.body).to include("Content can&#39;t be blank")
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
