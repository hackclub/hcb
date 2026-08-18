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

    describe "GET #edit" do
      it "renders the full page form" do
        get :edit, params: { item_id: item.hashid }
        expect(response).to be_successful
      end

      it "renders the inline form partial" do
        get :edit, params: { item_id: item.hashid, inline: "true", location: "ledger" }
        expect(response).to be_successful
        expect(response.body).to include("<form")
      end
    end

    describe "PATCH #update" do
      it "updates the memo and redirects" do
        patch :update, params: { item_id: item.hashid, ledger_item: { memo: "New memo" } }
        expect(response).to redirect_to(ledger_item_path(item))
        expect(item.reload.memo).to eq("New memo")
      end

      it "updates the memo and renders the inline partial" do
        patch :update, params: { item_id: item.hashid, ledger_item: { memo: "Another memo", inline: "true", location: "ledger" } }
        expect(response).to be_successful
        expect(item.reload.memo).to eq("Another memo")
        expect(response.body).to include("Another memo")
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
      patch :update, params: { item_id: item.hashid, ledger_item: { memo: "Nope" } }
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(item.reload.memo).not_to eq("Nope")
    end
  end
end
