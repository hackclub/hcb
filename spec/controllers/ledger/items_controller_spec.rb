# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::ItemsController, type: :controller do
  include SessionSupport
  render_views

  let(:event) { create(:event) }
  let(:ledger) { event.ledger }
  let(:item) { create(:ledger_item) }

  before do
    create(:ledger_mapping, :on_primary, ledger:, ledger_item: item)
  end

  context "as a member" do
    let(:member_user) { create(:user) }

    before do
      create(:organizer_position, event:, user: member_user, role: :member)
      create_session(member_user, verified: true)
    end

    describe "PATCH #rename" do
      it "updates the memo and responds with a turbo stream" do
        patch :rename, params: { item_id: item.hashid, ledger_item: { memo: "New memo" } }

        expect(response).to be_successful
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(item.reload.memo).to eq("New memo")
        expect(response.body).to include("New memo")
        expect(response.body).to include("turbo-stream")
      end
    end

    describe "GET #show" do
      # TODO: TEMPORARY — comments are being migrated from HcbCode to
      # Ledger::Item; this asserts the transitional union rendered by both
      # commentables (Ledger::Item::all_comments) until that finishes.
      it "renders comments from both the item and its hcb_code" do
        allow(FlipperGroups).to receive(:hcb_engineer?).and_return(true)
        hcb_code = create(:hcb_code, ledger_item: item)
        # CommentPolicy#users needs an event to determine who can see the comment;
        # for HcbCode that comes from its canonical (pending) transactions.
        cpt = create(:canonical_pending_transaction)
        cpt.update_column(:hcb_code, hcb_code.hcb_code)
        create(:canonical_pending_event_mapping, canonical_pending_transaction: cpt, event:)

        item_comment = create(:comment, commentable: item, user: member_user, content: "comment on the ledger item")
        hcb_code_comment = create(:comment, commentable: hcb_code, user: member_user, content: "comment on the hcb code")

        get :show, params: { id: item.hashid }

        expect(response).to be_successful
        expect(response.body).to include(item_comment.content)
        expect(response.body).to include(hcb_code_comment.content)
      end
    end
  end

  context "as a reader (not a member)" do
    let(:reader_user) { create(:user) }

    before do
      create(:organizer_position, event:, user: reader_user, role: :reader)
      create_session(reader_user, verified: true)
    end

    it "denies renaming" do
      patch :rename, params: { item_id: item.hashid, ledger_item: { memo: "Nope" } }
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(item.reload.memo).not_to eq("Nope")
    end
  end
end
