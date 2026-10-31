# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentsController do
  include SessionSupport

  describe "#create" do
    let(:user) { create(:user, :make_admin) }
    let(:hcb_code) { create(:canonical_pending_transaction).local_hcb_code }

    before { create_session(user, verified: true) }

    def post_blank_comment
      post(:create, params: { hcb_code_id: hcb_code.hashid, comment: { commentable_type: "HcbCode", commentable_id: hcb_code.id, content: "" } })
    end

    it "flashes validation errors back into the frame it was submitted from" do
      request.headers["Turbo-Frame"] = hcb_code.public_id

      post_blank_comment

      expect(response).to redirect_to(hcb_code)
      expect(flash[:error]).to eq("Content can't be blank")
    end

    context "outside of a frame" do
      render_views

      it "re-renders the form with errors" do
        post_blank_comment

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Content can&#39;t be blank")
      end
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
