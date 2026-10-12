# frozen_string_literal: true

require "rails_helper"

RSpec.describe LedgersController, type: :controller do
  include SessionSupport

  let(:admin) { create(:user, :make_admin) }
  let(:event) { create(:event) }
  let(:ledger) { event.ledger }

  before { create_session(admin, verified: true) }

  describe "GET #show" do
    it "returns success" do
      get :show, params: { id: ledger.to_param }
      expect(response).to be_successful
    end

    it "returns success with ledger items" do
      items = create_list(:ledger_item, 3)
      items.each do |item|
        create(:ledger_mapping, ledger:, ledger_item: item, on_primary_ledger: true)
      end

      get :show, params: { id: ledger.to_param }
      expect(response).to be_successful
    end

    describe "memo rename affordance" do
      render_views

      let(:item) { create(:ledger_item) }

      before do
        create(:ledger_mapping, :on_primary, ledger:, ledger_item: item)
        # Pin ct_count so this item (which has no real CTs) isn't filtered out
        # as empty (see Ledger::Query#execute).
        item.update_columns(ct_count: 1)
      end

      it "renders the shift-click-to-rename widget with the memo as alt text" do
        get :show, params: { id: ledger.to_param }

        expect(response).to be_successful
        expect(response.body).to include("data-controller=\"memo\"")
        expect(response.body).to include("data-action=\"click-&gt;memo#editOnShiftClick\"")
        expect(response.body).to include("aria-label=\"Shift+click to rename this transaction\"")
        expect(response.body).to include("title=\"#{item.memo}\"")
      end

      context "as a member without admin/auditor access" do
        let(:member_user) { create(:user) }

        before do
          create(:organizer_position, event:, user: member_user, role: :member)
          Flipper.enable_actor(:new_ledger_2026_07_17, member_user)
          create_session(member_user, verified: true)
        end

        it "still renders the rename widget" do
          get :show, params: { id: ledger.to_param }

          expect(response).to be_successful
          expect(response.body).to include("data-action=\"click-&gt;memo#editOnShiftClick\"")
        end
      end

      context "as a reader who can view the ledger but can't rename" do
        let(:reader_user) { create(:user) }

        before do
          create(:organizer_position, event:, user: reader_user, role: :reader)
          Flipper.enable_actor(:new_ledger_2026_07_17, reader_user)
          create_session(reader_user, verified: true)
        end

        it "falls back to a plain link instead of the rename widget" do
          get :show, params: { id: ledger.to_param }

          expect(response).to be_successful
          expect(response.body).not_to include("data-action=\"click-&gt;memo#editOnShiftClick\"")
          expect(response.body).to include("href=\"#{ledger_item_path(item)}\"")
        end
      end
    end
  end

end
