# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCodesController, type: :controller do
  include SessionSupport
  render_views

  describe "GET #show" do
    let(:event) {
      event = create(:event)
      create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)
      event
    }
    let(:ach_transfer) { create(:ach_transfer, event:) }
    let(:hcb_code) { ach_transfer.local_hcb_code }

    before { create_session(create(:user, :make_auditor), verified: true) }

    it "shows the Process button after the transfer can no longer be canceled" do
      ach_transfer.update_column(:aasm_state, "deposited")

      get :show, params: { id: hcb_code.hashid }

      expect(response).to be_successful
      expect(response.body).to include(%(action="#{ach_start_approval_admin_path(ach_transfer)}"))
      expect(response.body).not_to include("Cancel transfer")
    end

    it "links each CPT to its own page" do
      cpt = hcb_code.canonical_pending_transactions.sole

      get :show, params: { id: hcb_code.hashid }

      expect(response.body).to include(%(href="#{canonical_pending_transaction_path(cpt)}">CPT #{cpt.id}</a>))
    end

    context "for a Wise transfer whose pending transaction is not grouped under its HCB code" do
      let(:wise_transfer) do
        WiseTransfer.create!(
          event:,
          user: create(:user),
          amount_cents: 100_00,
          currency: "GBP",
          recipient_country: "GB",
          recipient_name: "Fiona Hackworth",
          recipient_email: "fiona@example.com",
          payment_for: "Speaker fee",
          # Set so the after_create hook skips generate_quote!, which would
          # otherwise reach for a live exchange rate.
          quoted_usd_amount_cents: 130_00
        )
      end
      let(:hcb_code) { wise_transfer.local_hcb_code }

      before do
        # Reproduces production rows where the CPT's hcb_code write failed, so
        # HcbCode#pt is nil even though the transfer and its CPT both exist.
        wise_transfer.canonical_pending_transaction.update_column(:hcb_code, nil)
      end

      it "renders and still warns that the USD amount may change" do
        get :show, params: { id: hcb_code.hashid }

        expect(response).to be_successful
        expect(response.body).to include("might change")
      end

      it "drops the warning once a canonical transaction has settled the transfer" do
        create(:canonical_transaction, amount_cents: -130_00).update_column(:hcb_code, hcb_code.hcb_code)

        get :show, params: { id: hcb_code.hashid }

        expect(response).to be_successful
        expect(response.body).not_to include("might change")
      end
    end

    describe "\"Repay this\"" do
      let(:event) { create(:event) }
      let(:user) { create(:user) }
      let(:expense) { create(:canonical_transaction, event:, amount_cents: -100_00, memo: "Pizza") }
      let(:repay_link) { new_disbursement_path(event_id: event.slug, repaid_ledger_item_id: expense.ledger_item.hashid) }

      before do
        create(:organizer_position, event:, user:)
        create_session(user, verified: true)
      end

      it "links to a repayment of an unrepaid expense" do
        get :show, params: { id: expense.local_hcb_code.hashid }

        expect(response).to be_successful
        expect(response.body).to include("Repay this")
        expect(response.body).to include(%(href="#{ERB::Util.html_escape(repay_link)}"))
      end

      it "is hidden once the expense has been repaid" do
        disbursement = create(:disbursement, event:)
        Repayment.new(disbursement:, repaid_ledger_item: expense.ledger_item, amount_cents: 100_00).save!(validate: false)

        get :show, params: { id: expense.local_hcb_code.hashid }

        expect(response).to be_successful
        expect(response.body).not_to include("Repay this")
      end

      it "is hidden for income" do
        income = create(:canonical_transaction, event:, amount_cents: 100_00)

        get :show, params: { id: income.local_hcb_code.hashid }

        expect(response).to be_successful
        expect(response.body).not_to include("Repay this")
      end
    end
  end
end
