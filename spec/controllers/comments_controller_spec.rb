# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentsController do
  include SessionSupport

  describe "#create" do
    let(:event) { create(:event) }
    let(:hcb_code) { create(:canonical_pending_transaction, event:).local_hcb_code }
    let(:redirect_url) { "http://test.host#{hcb_code.popover_path}" }

    before do
      user = create(:user)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)
      request.headers["Turbo-Frame"] = hcb_code.public_id
    end

    it "returns an invalid comment to the popover it came from, with the error" do
      post(:create, params: { hcb_code_id: hcb_code.hashid, comment: { commentable_type: "HcbCode", commentable_id: hcb_code.id, content: "", redirect_url: } })

      expect(hcb_code.comments).to be_empty
      expect(flash[:error]).to eq("Content can't be blank")
      expect(response).to redirect_to(redirect_url)
    end

    it "never redirects an invalid comment off-site" do
      post(:create, params: { hcb_code_id: hcb_code.hashid, comment: { commentable_type: "HcbCode", commentable_id: hcb_code.id, content: "", redirect_url: "https://evil.example.com" } })

      expect(response).to redirect_to(hcb_code_path(hcb_code))
    end

    it "still renders the form for an invalid comment outside a frame" do
      request.headers["Turbo-Frame"] = nil

      post(:create, params: { hcb_code_id: hcb_code.hashid, comment: { commentable_type: "HcbCode", commentable_id: hcb_code.id, content: "", redirect_url: } })

      expect(response).to have_http_status(:unprocessable_content)
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
