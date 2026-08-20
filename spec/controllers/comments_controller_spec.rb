# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentsController do
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

  # TODO: TEMPORARY — part of migrating comments from HcbCode to Ledger::Item;
  # this asserts new comments can attach directly to a Ledger::Item, which is
  # what comments/_form now submits to (see hcb_codes/show, ledger/items/show).
  describe "#create" do
    include SessionSupport

    let(:event) { create(:event) }
    let(:ledger) { event.ledger }
    let(:item) { create(:ledger_item) }
    let(:member_user) { create(:user) }

    before do
      create(:ledger_mapping, :on_primary, ledger:, ledger_item: item)
      create(:organizer_position, event:, user: member_user, role: :member)
      create_session(member_user, verified: true)
    end

    it "creates a comment attached to a Ledger::Item" do
      expect {
        post :create, params: {
          ledger_item_id: item.hashid,
          comment: {
            content: "a new comment",
            commentable_type: "Ledger::Item",
            commentable_id: item.id
          }
        }
      }.to change { item.comments.count }.by(1)

      comment = item.comments.last
      expect(comment.content).to eq("a new comment")
      expect(comment.commentable).to eq(item)
    end
  end
end
