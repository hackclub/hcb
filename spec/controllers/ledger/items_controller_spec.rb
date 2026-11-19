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

    describe "POST #toggle_tag" do
      let(:tag) { event.tags.create!(label: "Snacks", emoji: "🍕", color: "muted") }

      it "adds the tag and then removes it on a second toggle" do
        post :toggle_tag, params: { item_id: item.hashid, tag_id: tag.id }
        expect(item.reload.tags).to include(tag)

        post :toggle_tag, params: { item_id: item.hashid, tag_id: tag.id }
        expect(item.reload.tags).not_to include(tag)
      end

      it "refuses a tag from another organization" do
        other_event = create(:event)
        create(:organizer_position, user: member_user, event: other_event, role: :member)
        other_tag = other_event.tags.create!(label: "Other", emoji: "🎉", color: "red")

        post :toggle_tag, params: { item_id: item.hashid, tag_id: other_tag.id }

        expect(item.reload.tags).to be_empty
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

  describe "GET #show" do
    context "when the item has no HCB code" do
      it "renders for an auditor" do
        create_session(create(:user, :make_auditor), verified: true)

        get :show, params: { id: item.hashid }

        expect(response).to be_successful
        expect(response.body).to include(item.memo)
      end

      it "responds with not found for a non-auditor" do
        create_session(create(:user), verified: true)

        expect { get :show, params: { id: item.hashid } }.to raise_error(ActionController::RoutingError)
      end
    end

    context "when asked to reverse a receipt pairing" do
      let(:receipt) do
        Receipt.create!(receiptable: item, user: create(:user), upload_method: :email_receipt_bin,
                        file: { io: file_fixture("receipt.png").open, filename: "receipt.png" })
      end

      before { create(:hcb_code, code_type: ::TransactionGroupingEngine::Calculate::HcbCode::UNKNOWN_CODE, ledger_item: item) }

      it "carries the receipt through the redirect to the HCB code page for a non-auditor" do
        create(:organizer_position, event:, user: (user = create(:user)))
        create_session(user, verified: true)

        get :show, params: { id: item.hashid, reverse: receipt.id }

        expect(response).to redirect_to(hcb_code_path(item.hcb_code, reverse: receipt.id))
      end

      it "asks an auditor to confirm the reversal" do
        create_session(create(:user, :make_auditor), verified: true)

        get :show, params: { id: item.hashid, reverse: receipt.id }

        expect(response).to be_successful
        expect(response.body).to include("Reverse receipt pairing")
        expect(response.body).to include(reverse_receipt_path(receipt.id, format: :html))
      end
    end

    it "updates the counts on the item's ledger row when shown in a popover" do
      create_session(create(:user, :make_auditor), verified: true)
      target = "turbo-stream[action='replace'][target='badges_ledger_item_#{item.id}']"

      get :show, params: { id: item.hashid, frame: true }
      expect(Nokogiri::HTML5(response.body).at_css(target)).to be_present

      get :show, params: { id: item.hashid }
      expect(Nokogiri::HTML5(response.body).at_css(target)).to be_nil
    end

    it "links each CPT to its own page for an auditor" do
      cpt = create(:canonical_pending_transaction)
      cpt_item = cpt.reload.ledger_item
      cpt_item.ledger_mappings.delete_all
      create(:ledger_mapping, :on_primary, ledger:, ledger_item: cpt_item)
      create_session(create(:user, :make_auditor), verified: true)

      get :show, params: { id: cpt_item.hashid }

      expect(response).to be_successful
      expect(response.body).to include(%(href="#{canonical_pending_transaction_path(cpt)}">CPT #{cpt.id}</a>))
    end

    it "shows a scheduled repayment before it has been sent" do
      source_event = create(:event, :with_positive_balance)
      expense = create(:canonical_transaction, event:, amount_cents: -100_00, category_slug: "food-fun")
      disbursement = DisbursementService::Create.new(
        name: "Paying back pizza",
        amount: "100.00",
        requested_by_id: create(:user, :make_admin).id,
        source_event_id: source_event.id,
        destination_event_id: event.id,
        scheduled_on: Date.tomorrow,
        transfer_type: "repayment",
        repaid_ledger_item_ids: [expense.ledger_item.id]
      ).run
      # Scheduled transfers only reach the recipient once they're sent.
      expect(disbursement.incoming_disbursement.ledger_item).to be_nil
      outgoing_item = disbursement.outgoing_disbursement.ledger_item
      create_session(create(:user, :make_auditor), verified: true)

      get :show, params: { id: expense.ledger_item.hashid }

      expect(response).to be_successful
      expect(response.body).to include("Repaid by")
      expect(response.body).to include(ledger_item_path(outgoing_item))
    end

    it "shows the Process button after the transfer can no longer be canceled" do
      create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)
      ach_transfer = create(:ach_transfer, event:)
      ach_transfer.update_column(:aasm_state, "deposited")
      ach_item = ach_transfer.reload.ledger_item
      create_session(create(:user, :make_auditor), verified: true)

      get :show, params: { id: ach_item.hashid }

      expect(response).to be_successful
      expect(response.body).to include(%(action="#{ach_start_approval_admin_path(ach_transfer)}"))
      expect(response.body).not_to include("Cancel transfer")
    end

    it "renders a fee reimbursement group with the reimbursements topped up that week" do
      create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK)
      allow_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
      group = create(:fee_reimbursement_group, key: "2026_42")
      invoice = create(:invoice)
      create(:fee_reimbursement, invoice:, fee_reimbursement_group: group, amount: 1_23)
      create_session(create(:user, :make_auditor), verified: true)

      get :show, params: { id: group.ledger_item.hashid }

      expect(response).to be_successful
      expect(response.body).to include(group.memo)
      expect(response.body).to include("Stripe fee reimbursements")
      expect(response.body).to include(ERB::Util.html_escape(invoice.event.name))
      expect(response.body).to include("$1.23")
    end

    context "for a transfer staff process by hand" do
      let(:event) { create(:event, :with_positive_balance) }

      let(:wire) do
        stub_request(:get, "https://api.column.com/institutions/DEUTDEDB")
          .to_return_json(status: 200, body: { country_code: "DE" })
        create(:wire, :pending, event:)
      end

      let(:paypal_transfer) do
        # New PayPal transfers are refused at validation, so save past it to
        # stand in for one created before that.
        PaypalTransfer.new(
          event:,
          user: create(:user),
          amount_cents: 25_00,
          memo: "Stickers",
          payment_for: "Stickers",
          recipient_name: "Orpheus",
          recipient_email: "orpheus@example.com"
        ).tap { |transfer| transfer.save!(validate: false) }
      end

      def ledger_item_for(transfer)
        create(:ledger_item, linked_object: transfer).tap do |ledger_item|
          create(:ledger_mapping, :on_primary, ledger: event.ledger, ledger_item:)
        end
      end

      [:make_auditor, :make_admin].each do |role|
        it "shows the Process button on a wire to a user with #{role.to_s.delete_prefix("make_")} access" do
          create_session(create(:user, role), verified: true)

          get :show, params: { id: ledger_item_for(wire).hashid }

          expect(response).to be_successful
          expect(response.body).to include(%(action="#{wire_process_admin_path(wire)}"))
        end

        it "shows the Process button on a PayPal transfer to a user with #{role.to_s.delete_prefix("make_")} access" do
          create_session(create(:user, role), verified: true)

          get :show, params: { id: ledger_item_for(paypal_transfer).hashid }

          expect(response).to be_successful
          expect(response.body).to include(%(action="#{paypal_transfer_process_admin_path(paypal_transfer)}"))
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
