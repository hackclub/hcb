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

  describe "#create on a transfer between organizations" do
    let(:user) { create(:user, :make_admin) }
    let(:disbursement) { create(:disbursement) }
    let(:hcb_code) { HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code) }

    before { create_session(user, verified: true) }

    def post_comment(comment_target)
      post(:create, params: { hcb_code_id: hcb_code.hashid, comment: { commentable_type: "HcbCode", commentable_id: hcb_code.id, comment_target:, content: "Thanks!" } })
    end

    it "keeps a private comment on the transaction" do
      expect { post_comment("private") }.to change { hcb_code.comments.count }.by(1)
    end

    it "puts a shared comment on the transfer" do
      expect { post_comment("shared") }.to change { disbursement.comments.count }.by(1)
      expect(hcb_code.comments).to be_empty
    end
  end

  describe "#destroy" do
    render_views

    it "streams the new comment count into the item's ledger row" do
      create_session(create(:user, :make_admin), verified: true)
      hcb_code = create(:canonical_pending_transaction).local_hcb_code
      comments = create_list(:comment, 2, commentable: hcb_code)
      ledger_item = hcb_code.ledger_item.reload
      expect(ledger_item.comment_count).to eq(2)

      delete(:destroy, params: { id: comments.first.id }, format: :turbo_stream)

      stream = Nokogiri::HTML5.fragment(response.body).at_css("turbo-stream[target='badges_ledger_item_#{ledger_item.id}']")
      expect(stream["action"]).to eq("replace")
      expect(stream.inner_html).to include('aria-label="1 comment"')
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
