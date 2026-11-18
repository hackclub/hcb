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

    it "renders a charge on a card grant for its grantee" do
      grantor = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      grantee = create(:user)
      card = create(:stripe_card, :with_stripe_id, event: grantor, stripe_cardholder: create(:stripe_cardholder, user: grantee))
      card_grant = create(:card_grant, event: grantor, user: grantee, stripe_card: card)
      charge = create(:canonical_pending_transaction, event: grantor, amount_cents: -1000, raw_pending_stripe_transaction: create(:raw_pending_stripe_transaction, stripe_card: card, stripe_merchant_category_code: "5462"))
      Ledger::Mapping.map_primary!(ledger: card_grant.ledger, ledger_item: charge.local_hcb_code.ledger_item, mapped_by: create(:user, :make_admin))
      create_session(grantee, verified: true)

      get :show, params: { id: charge.local_hcb_code.hashid }

      expect(response).to be_successful
      expect(response.body).to include(charge.local_hcb_code.public_id)
      expect(response.body).to include("Bakeries (bakeries)")

      # The grant page's ledger rows open the charge in a popover.
      get :show, params: { id: charge.local_hcb_code.hashid, frame: true }

      expect(response).to be_successful
      expect(response.body).to include("Address check")
    end

    it "lists the transaction's splits and what is left over" do
      # Factory transactions get an `HCB-000-<id>` code, and settled and pending
      # ones have separate id sequences: one that matched this event's pending
      # transaction would be grouped with it. Pick an id neither can share.
      transaction = create(:canonical_transaction, id: [CanonicalTransaction.maximum(:id).to_i, CanonicalPendingTransaction.maximum(:id).to_i].max + 1_000, event:, amount_cents: -100_00)
      transaction.splits.create!(amount_cents: -60_00, memo: "Repaid by the PTA", category: TransactionCategory.find_or_create_by!(slug: "repayment"))
      expense = transaction.local_hcb_code

      get :show, params: { id: expense.hashid }

      expect(response.body).to include("Repaid by the PTA", "$60.00", "$40.00", "Rest of the transaction")
      # Categories are for reporting and aren't shown on the transaction
      expect(Nokogiri::HTML(response.body).at_css("#splits").text).not_to include("Repayment")
      expect(Nokogiri::HTML(response.body).css("#splits [style]").map { |segment| segment["style"] }).to eq(["width: 60.0%", "width: 40.0%"])
    end

    it "links each CPT to its own page" do
      cpt = hcb_code.canonical_pending_transactions.sole

      get :show, params: { id: hcb_code.hashid }

      expect(response.body).to include(%(href="#{canonical_pending_transaction_path(cpt)}">CPT #{cpt.id}</a>))
    end

    # Posting a comment in the popover reloads it, which is when the ledger row
    # behind it picks up the new comment count.
    it "updates the counts on the item's ledger row when shown in a popover" do
      item_hcb_code = create(:canonical_pending_transaction, event:, amount_cents: -1000).local_hcb_code
      target = "turbo-stream[action='replace'][target='badges_ledger_item_#{item_hcb_code.ledger_item.id}']"

      get :show, params: { id: item_hcb_code.hashid, frame: true }
      expect(Nokogiri::HTML5(response.body).at_css(target)).to be_present

      get :show, params: { id: item_hcb_code.hashid }
      expect(Nokogiri::HTML5(response.body).at_css(target)).to be_nil
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
        # Settle through the short code in the memo, the way the bank memo does
        # in production. Without it the factory CT gets the catch-all code
        # HCB-000-<ct.id>, which collides with the `event` let's factory CPT
        # (HCB-000-<cpt.id>) whenever the two ids happen to match. The CT then
        # joins that CPT's HCB code and ledger item, and assign_ledger_item
        # raises.
        create(:canonical_transaction, amount_cents: -130_00, memo: "HCB-#{hcb_code.short_code}")

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
        repayment = disbursement.build_repayment
        repayment.allocations.build(repaid_ledger_item: expense.ledger_item, amount_cents: 100_00)
        repayment.save!(validate: false)

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

    context "marking a repayment" do
      render_views

      let(:event) { create(:event) }
      let(:user) { create(:user) }
      let(:expense) { create(:canonical_transaction, event:, amount_cents: -100_00, memo: "Pizza") }
      let(:income) { create(:canonical_transaction, event:, amount_cents: 100_00, memo: "Venmo from Sam") }

      before do
        create(:organizer_position, event:, user:)
        create_session(user, verified: true)
      end

      it "offers income a match with an expense of the same amount" do
        expense

        get :show, params: { id: income.local_hcb_code.hashid }

        expect(response.body).to include("Mark as a repayment")
        expect(response.body).to include(candidates_ledger_item_repayment_path(income.ledger_item))
      end

      it "offers an expense a match with income of the same amount" do
        income

        get :show, params: { id: expense.local_hcb_code.hashid }

        expect(response.body).to include("Mark as repaid")
      end

      it "is hidden when nothing has the same amount" do
        create(:canonical_transaction, event:, amount_cents: 50_00)

        get :show, params: { id: expense.local_hcb_code.hashid }

        expect(response.body).not_to include("Mark as repaid")
      end

      it "is hidden once the expense has been repaid" do
        RepaymentService::Mark.new(ledger_item: income.ledger_item.reload, other_ledger_item_hashid: expense.ledger_item.reload.hashid, created_by: user).run
        create(:canonical_transaction, event:, amount_cents: 100_00)

        get :show, params: { id: expense.local_hcb_code.hashid }

        expect(response.body).not_to include("Mark as repaid")
      end
    end
  end
end
