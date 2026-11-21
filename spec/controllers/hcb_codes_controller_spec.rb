# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCodesController, type: :controller do
  include SessionSupport
  render_views

  describe "GET #attach_receipt" do
    it "links to the lost receipt form on the signed upload page" do
      cpt = create(:canonical_pending_transaction, amount_cents: -1234, raw_pending_stripe_transaction: create(:raw_pending_stripe_transaction))
      create(:canonical_pending_event_mapping, canonical_pending_transaction: cpt, event: create(:event))
      hcb_code = cpt.local_hcb_code

      secret = hcb_code.signed_id(purpose: :receipt_upload, expires_in: 1.day)
      get :attach_receipt, params: { id: hcb_code.hashid, s: secret }

      expect(response).to be_successful
      link = Nokogiri::HTML.fragment(response.body).at_css('a[href*="lost_receipt"]')
      expect(link["href"]).to include("s=#{secret}")
    end
  end

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

  describe "Process button" do
    let(:event) { create(:event, :with_positive_balance) }
    let(:member) { create(:user).tap { |user| create(:organizer_position, user:, event:, role: :manager) } }

    shared_examples "a Process button for staff" do
      it "is shown to an auditor" do
        create_session(create(:user, :make_auditor), verified: true)

        get :show, params: { id: transfer.local_hcb_code.hashid }

        expect(response).to be_successful
        expect(response.body).to include(%(action="#{process_path}"))
      end

      it "is shown to an admin" do
        create_session(create(:user, :make_admin), verified: true)

        get :show, params: { id: transfer.local_hcb_code.hashid }

        expect(response).to be_successful
        expect(response.body).to include(%(action="#{process_path}"))
      end

      it "is hidden from an organization manager" do
        create_session(member, verified: true)

        get :show, params: { id: transfer.local_hcb_code.hashid }

        expect(response).to be_successful
        expect(response.body).not_to include(process_path)
      end
    end

    context "on a wire" do
      let(:transfer) do
        stub_request(:get, "https://api.column.com/institutions/DEUTDEDB")
          .to_return_json(status: 200, body: { country_code: "DE" })
        create(:wire, :pending, event:, user: member)
      end
      let(:process_path) { wire_process_admin_path(transfer) }

      it_behaves_like "a Process button for staff"
    end

    context "on a PayPal transfer" do
      let(:transfer) do
        # New PayPal transfers are refused at validation, so save past it to
        # stand in for one created before that.
        PaypalTransfer.new(
          event:,
          user: member,
          amount_cents: 25_00,
          memo: "Stickers",
          payment_for: "Stickers",
          recipient_name: "Orpheus",
          recipient_email: "orpheus@example.com"
        ).tap { |paypal_transfer| paypal_transfer.save!(validate: false) }
      end
      let(:process_path) { paypal_transfer_process_admin_path(transfer) }

      it_behaves_like "a Process button for staff"
    end
  end
end
