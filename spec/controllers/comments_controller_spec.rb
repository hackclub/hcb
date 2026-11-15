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

      expect(response).to redirect_to(hcb_code.ledger_item)
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

  describe "#create on a transaction with a ledger item" do
    let(:user) { create(:user, :make_admin) }
    let(:hcb_code) { create(:canonical_pending_transaction).local_hcb_code }
    let(:ledger_item) { hcb_code.ledger_item }

    before { create_session(user, verified: true) }

    it "puts a comment posted to the ledger item on the item" do
      expect do
        post(:create, params: { ledger_item_id: ledger_item.hashid, comment: { commentable_type: "Ledger::Item", commentable_id: ledger_item.id, content: "Hi!" } })
      end.to change { ledger_item.comments.count }.by(1)

      expect(response).to redirect_to(ledger_item)
    end

    it "moves a comment posted to the HCB code onto its ledger item" do
      expect do
        post(:create, params: { hcb_code_id: hcb_code.hashid, comment: { commentable_type: "HcbCode", commentable_id: hcb_code.id, content: "Hi!" } })
      end.to change { ledger_item.comments.count }.by(1)

      expect(hcb_code.comments).to be_empty
    end

    it "puts a comment shared with the other side of a transfer on the transfer" do
      disbursement = create(:disbursement)
      ledger_item = create(:ledger_item, linked_object: disbursement.outgoing_disbursement)

      expect do
        post(:create, params: { ledger_item_id: ledger_item.hashid, comment: { commentable_type: "Ledger::Item", commentable_id: ledger_item.id, comment_target: "shared", content: "Thanks!" } })
      end.to change { disbursement.comments.count }.by(1)

      expect(ledger_item.comments).to be_empty
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

  describe "#edit" do
    render_views

    it "renders the nav for the ledger item's event" do
      create_session(create(:user, :make_admin), verified: true)
      event = create(:event, name: "Daydream Denver")
      item = create(:ledger_item)
      create(:ledger_mapping, :on_primary, ledger: event.ledger, ledger_item: item)
      comment = create(:comment, commentable: item)

      get(:edit, params: { id: comment.id })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Daydream Denver")
    end
  end

  describe "#destroy" do
    render_views

    it "streams the new comment count into the item's ledger row" do
      create_session(create(:user, :make_admin), verified: true)
      ledger_item = create(:canonical_pending_transaction).local_hcb_code.ledger_item
      comments = create_list(:comment, 2, commentable: ledger_item)
      ledger_item.reload
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
