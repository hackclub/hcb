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

    describe "POST #invoice_as_personal_transaction" do
      before { create(:hcb_code, ledger_item: item) }

      it "reports why the invoice couldn't be created rather than claiming one exists" do
        post :invoice_as_personal_transaction, params: { item_id: item.hashid }

        expect(flash[:error]).to include("Invoices can only be generated for card charges.")
        expect(response).to redirect_to(hcb_code_path(item.hcb_code))
        expect(PersonalTransaction.where(ledger_item: item)).not_to exist
      end

      context "when a repayment invoice already exists" do
        it "redirects to the existing invoice" do
          allow_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
          # Validations are skipped so this stands in for any already-invoiced
          # item; the branch under test only cares that a row is persisted.
          existing = PersonalTransaction.new(ledger_item: item, reporter: member_user, invoice: create(:invoice))
          existing.save!(validate: false)

          post :invoice_as_personal_transaction, params: { item_id: item.hashid }

          expect(flash[:error]).to eq("A repayment invoice already exists for this transaction.")
          expect(response).to redirect_to(invoice_path(existing.invoice))
          expect(PersonalTransaction.where(ledger_item: item).count).to eq(1)
        end
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
