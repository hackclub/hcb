# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminController do
  include SessionSupport

  describe "#disbursement_process" do
    render_views

    it "renders mission statements for the source and destination events" do
      admin = create(:user, :make_admin)
      source_event = create(:event, description: "Source mission statement")
      destination_event = create(:event, description: "Destination mission statement")
      disbursement = create(:disbursement, source_event:, event: destination_event)

      create_session(admin, verified: true)

      get :disbursement_process, params: { id: disbursement.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Source mission statement")
      expect(response.body).to include("Destination mission statement")
    end
  end

  describe "#fee_revenues" do
    render_views

    it "lists every organization with an uncharged fee balance and totals them" do
      admin = create(:user, :make_admin)
      fronted_org = create(:event, name: "Fronted Org", plan_type: Event::Plan::Standard)
      donation = create(:canonical_pending_transaction, amount_cents: 100_00, fronted: true)
      create(:canonical_pending_event_mapping, canonical_pending_transaction: donation, event: fronted_org)
      settled_org = create(:event, name: "Settled Org")
      create(:fee, canonical_event_mapping: nil, memo: "Revenue fee", event: settled_org, reason: :revenue, amount_cents_as_decimal: 5_00)

      create_session(admin, verified: true)

      get :fee_revenues

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Uncharged Fee Balance: $12.00")
      expect(response.body).to include("Fronted Org", "Settled Org")
    end
  end

  def create_sent_wise_transfer(event:, user:, wise_id: "1234567", usd_amount_cents: 130_00)
    WiseTransfer.create!(
      event:,
      user:,
      aasm_state: "sent",
      amount_cents: 100_00,
      currency: "GBP",
      recipient_country: "GB",
      recipient_name: "Fiona Hackworth",
      recipient_email: "fiona@example.com",
      payment_for: "Speaker fee",
      # Both are required once the transfer has been sent.
      wise_id:,
      wise_recipient_id: "0199a1f0-7c3a-4a0b-9b2e-6d1f8a3c5e47",
      sent_at: 1.day.ago,
      # Set so the after_create hook skips generate_quote!, which would
      # otherwise reach for a live exchange rate.
      quoted_usd_amount_cents: usd_amount_cents,
      usd_amount_cents:
    )
  end

  # A transfer whose outgoing transaction has settled, as after #set_wise_transfer.
  def deposited_wise_transfer(**attrs)
    wise_transfer = create_sent_wise_transfer(event: create(:event), user: create(:user), **attrs)
    outgoing = create(:canonical_transaction, amount_cents: -wise_transfer.usd_amount_cents)
    CanonicalPendingTransactionService::Settle.new(canonical_transaction: outgoing, canonical_pending_transaction: wise_transfer.canonical_pending_transaction).run!
    wise_transfer.tap { |t| t.update!(aasm_state: "deposited") }
  end

  describe "#set_wise_transfer" do
    it "maps the canonical transaction's ledger item onto the transfer's event ledger" do
      admin = create(:user, :make_admin)
      event = create(:event)
      wise_transfer = create_sent_wise_transfer(event:, user: admin)
      canonical_transaction = create(:canonical_transaction, amount_cents: -130_00)

      create_session(admin, verified: true)

      post :set_wise_transfer, params: { id: canonical_transaction.id, wise_transfer_id: wise_transfer.id }

      expect(wise_transfer.reload).to be_deposited
      expect(canonical_transaction.reload.event).to eq(event)
      expect(canonical_transaction.ledger_item.primary_ledger).to eq(event.ledger)
      expect(canonical_transaction.ledger_item.primary_mapping.mapped_by).to eq(admin)
    end

    it "keeps the transfer's HCB code when the transaction is remapped" do
      admin = create(:user, :make_admin)
      event = create(:event)
      wise_transfer = create_sent_wise_transfer(event:, user: admin)
      canonical_transaction = create(:canonical_transaction, amount_cents: -130_00)

      create_session(admin, verified: true)

      post :set_wise_transfer, params: { id: canonical_transaction.id, wise_transfer_id: wise_transfer.id }
      post :set_event, params: { id: canonical_transaction.id, event_id: event.id }

      expect(canonical_transaction.reload.hcb_code).to eq(wise_transfer.hcb_code)
    end
  end

  describe "#transaction" do
    render_views

    it "suggests the Wise transfer a refund names and offers the return search" do
      admin = create(:user, :make_admin)
      wise_transfer = deposited_wise_transfer
      returned = create(:canonical_transaction, amount_cents: 127_50, memo: "WISE INC 4567REFUND", transaction_source: create(:raw_plaid_transaction))

      create_session(admin, verified: true)

      get :transaction, params: { id: returned.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Suggested Wise return")
      expect(response.body).to include("Map as return of Wise transfer ##{wise_transfer.id}")
      expect(response.body).to include("Map to a Wise transfer return")
      expect(response.body).to include(wise_transfer_return_search_admin_index_path(canonical_transaction_id: returned.id))
    end

    it "offers outgoing Wise transfers, not returns, for an outgoing transaction" do
      admin = create(:user, :make_admin)
      outgoing = create(:canonical_transaction, amount_cents: -130_00, transaction_source: create(:raw_plaid_transaction))

      create_session(admin, verified: true)

      get :transaction, params: { id: outgoing.id }

      expect(response.body).to include("Map to a Wise transfer")
      expect(response.body).not_to include("Map to a Wise transfer return")
    end

    def suggested_return_for(memo:, amount_cents:)
      admin = create(:user, :make_admin)
      returned = create(:canonical_transaction, amount_cents:, memo:, transaction_source: create(:raw_plaid_transaction))
      create_session(admin, verified: true)

      get :transaction, params: { id: returned.id }

      controller.instance_variable_get(:@suggested_wise_return)
    end

    it "matches a refund to the transfer whose Wise ID ends in the memo's 4 digits" do
      expected = deposited_wise_transfer(wise_id: "987567568")
      deposited_wise_transfer(wise_id: "1111111") # same amount, different Wise ID

      expect(suggested_return_for(memo: "THE HACK FOUNDAT 7568REFUND", amount_cents: 120_00)).to eq(expected)
    end

    it "narrows Wise ID matches by amount" do
      deposited_wise_transfer(wise_id: "11111679", usd_amount_cents: 500_00)
      expected = deposited_wise_transfer(wise_id: "22221679", usd_amount_cents: 130_00)

      expect(suggested_return_for(memo: "WISE INC 1679REFUND", amount_cents: 128_00)).to eq(expected)
    end

    it "doesn't suggest a transfer when the memo's Wise ID matches none" do
      deposited_wise_transfer(wise_id: "1111111")

      expect(suggested_return_for(memo: "THE HACK FOUNDAT 7568REFUND", amount_cents: 130_00)).to be_nil
    end

    it "doesn't suggest a transfer by amount alone" do
      deposited_wise_transfer(wise_id: "1111111")

      expect(suggested_return_for(memo: "WISE US INC REFUND", amount_cents: 130_00)).to be_nil
    end

    it "doesn't suggest a transfer once the refund is mapped to one" do
      admin = create(:user, :make_admin)
      wise_transfer = deposited_wise_transfer(wise_id: "987567568")
      returned = create(:canonical_transaction, amount_cents: 127_50, memo: "THE HACK FOUNDAT 7568REFUND", transaction_source: create(:raw_plaid_transaction))
      create_session(admin, verified: true)

      post :set_wise_transfer_return, params: { id: returned.id, wise_transfer_id: wise_transfer.id, reason: "Account closed" }
      get :transaction, params: { id: returned.id }

      expect(wise_transfer.reload).to be_failed
      expect(controller.instance_variable_get(:@suggested_wise_return)).to be_nil
      expect(response.body).not_to include("Suggested Wise return")
    end
  end

  describe "#wise_transfer_return_search" do
    def search(memo:, amount_cents: 127_50, q: nil)
      returned = create(:canonical_transaction, amount_cents:, memo:)
      create_session(create(:user, :make_admin), verified: true)
      get :wise_transfer_return_search, params: { canonical_transaction_id: returned.id, q: }.compact, format: :json
      JSON.parse(response.body).map { |option| option["value"].to_i }
    end

    it "lists only the recommended transfers until something is typed: Wise ID matches first, then about the amount" do
      by_wise_id = deposited_wise_transfer(wise_id: "55554101", usd_amount_cents: 900_00)
      close = deposited_wise_transfer(usd_amount_cents: 130_00)
      closer = deposited_wise_transfer(usd_amount_cents: 128_00)
      deposited_wise_transfer(usd_amount_cents: 500_00) # too far off
      deposited_wise_transfer(usd_amount_cents: 127_00).update!(sent_at: 1.year.ago) # too old
      create_sent_wise_transfer(event: create(:event), user: create(:user), usd_amount_cents: 127_00) # not deposited yet

      expect(search(memo: "WISE INC 4101REFUND")).to eq([by_wise_id.id, closer.id, close.id])
      expect(search(memo: "WISE INC REFUND")).to eq([closer.id, close.id])
    end

    it "searches every deposited or failed transfer by ID, Wise ID, or recipient" do
      old = deposited_wise_transfer(wise_id: "99887766", usd_amount_cents: 900_00).tap { |t| t.update!(sent_at: 2.years.ago) }
      other = deposited_wise_transfer(wise_id: "1111111", usd_amount_cents: 900_00)
      sent = create_sent_wise_transfer(event: create(:event), user: create(:user), wise_id: "22887766")

      expect(search(memo: "WISE INC REFUND", q: "7766")).to eq([old.id])
      expect(search(memo: "WISE INC REFUND", q: "##{other.id}")).to include(other.id)
      expect(search(memo: "WISE INC REFUND", q: "fiona")).to contain_exactly(old.id, other.id)
      expect(search(memo: "WISE INC REFUND", q: "##{sent.id}")).not_to include(sent.id)
    end
  end

  describe "#set_wise_transfer_return" do
    def map_outgoing!(wise_transfer)
      outgoing = create(:canonical_transaction, amount_cents: -130_00)
      post :set_wise_transfer, params: { id: outgoing.id, wise_transfer_id: wise_transfer.id }
      expect(wise_transfer.reload).to be_deposited
      outgoing.reload
    end

    it "nets the returned funds against the original transfer and marks it failed" do
      admin = create(:user, :make_admin)
      event = create(:event)
      wise_transfer = create_sent_wise_transfer(event:, user: admin)
      create_session(admin, verified: true)
      outgoing = map_outgoing!(wise_transfer)
      returned = create(:canonical_transaction, amount_cents: 127_50, memo: "WISE US INC REFUND")

      post :set_wise_transfer_return, params: { id: returned.id, wise_transfer_id: wise_transfer.id, reason: "Account closed" }

      expect(flash[:error]).to be_nil
      returned.reload
      expect(returned.event).to eq(event)
      expect(returned.hcb_code).to eq(wise_transfer.hcb_code)
      expect(returned.ledger_item).to eq(outgoing.ledger_item)
      expect(returned.fee.reason).to eq("transfer_returned")
      expect(returned.ledger_item.reload.amount_cents).to eq(-2_50)

      expect(wise_transfer.reload).to be_failed
      expect(wise_transfer.return_reason).to eq("Account closed")
      # The pending transaction already settled, so it must not also be declined.
      expect(wise_transfer.canonical_pending_transaction.reload).not_to be_declined
    end

    it "requires a failure reason, since it's emailed to the user" do
      admin = create(:user, :make_admin)
      event = create(:event)
      wise_transfer = create_sent_wise_transfer(event:, user: admin)
      create_session(admin, verified: true)
      map_outgoing!(wise_transfer)
      returned = create(:canonical_transaction, amount_cents: 127_50)

      post :set_wise_transfer_return, params: { id: returned.id, wise_transfer_id: wise_transfer.id, reason: " " }

      expect(flash[:error]).to match(/failure reason/)
      expect(returned.reload.hcb_code).not_to eq(wise_transfer.hcb_code)
      expect(returned.canonical_event_mapping).to be_nil
      expect(wise_transfer.reload).to be_deposited
    end

    it "maps a return onto a transfer ops already marked as failed, keeping its reason" do
      admin = create(:user, :make_admin)
      event = create(:event)
      wise_transfer = create_sent_wise_transfer(event:, user: admin)
      create_session(admin, verified: true)
      map_outgoing!(wise_transfer)
      wise_transfer.mark_failed!("Recipient bank rejected it")
      returned = create(:canonical_transaction, amount_cents: 127_50)

      post :set_wise_transfer_return, params: { id: returned.id, wise_transfer_id: wise_transfer.id }

      expect(flash[:error]).to be_nil
      expect(returned.reload.hcb_code).to eq(wise_transfer.hcb_code)
      expect(wise_transfer.reload).to be_failed
      expect(wise_transfer.return_reason).to eq("Recipient bank rejected it")
    end

    context "when the transfer paid out a reimbursement" do
      include ActiveJob::TestHelper

      let!(:system_user) { create(:user, id: User::SYSTEM_USER_ID) }

      # Payout holdings create a pending transaction on the clearinghouse event
      # on create, so insert one directly, as other specs do.
      def attach_payout_holding(wise_transfer)
        report = create(:reimbursement_report, aasm_state: :reimbursed)
        Reimbursement::PayoutHolding.insert_all([{
                                                  reimbursement_reports_id: report.id, amount_cents: 130_00, wise_transfer_id: wise_transfer.id,
                                                  aasm_state: "sent", created_at: Time.current, updated_at: Time.current
                                                }])
        Reimbursement::PayoutHolding.find_by!(wise_transfer_id: wise_transfer.id)
      end

      it "cancels the reimbursement report once the refund is mapped, emailing the user once" do
        admin = create(:user, :make_admin)
        wise_transfer = create_sent_wise_transfer(event: create(:event), user: admin)
        create_session(admin, verified: true)
        map_outgoing!(wise_transfer)
        payout_holding = attach_payout_holding(wise_transfer)
        reversed = []
        allow_any_instance_of(Reimbursement::PayoutHolding).to receive(:reverse!) { |holding| reversed << holding.id }
        returned = create(:canonical_transaction, amount_cents: 127_50)

        expect {
          post :set_wise_transfer_return, params: { id: returned.id, wise_transfer_id: wise_transfer.id, reason: "Account closed" }
        }.to have_enqueued_mail(ReimbursementMailer, :wise_transfer_failed)
          .with(params: a_hash_including(reason: "Account closed", cancelled: true), args: [])

        # Only the cancellation email, not also a "will be cancelled" one.
        mails = enqueued_jobs.select { |job| job["arguments"][0..1] == ["ReimbursementMailer", "wise_transfer_failed"] }
        expect(mails.size).to eq(1)
        expect(flash[:error]).to be_nil
        expect(wise_transfer.reload).to be_failed
        expect(reversed).to eq([payout_holding.id])
      end

      it "cancels the report when the refund arrives after ops marked the transfer failed" do
        admin = create(:user, :make_admin)
        wise_transfer = create_sent_wise_transfer(event: create(:event), user: admin)
        create_session(admin, verified: true)
        map_outgoing!(wise_transfer)
        payout_holding = attach_payout_holding(wise_transfer)
        reversed = []
        allow_any_instance_of(Reimbursement::PayoutHolding).to receive(:reverse!) { |holding| reversed << holding.id }

        wise_transfer.mark_failed!("Recipient bank rejected it")
        expect(reversed).to be_empty # marking it failed alone keeps the holding in the clearinghouse

        returned = create(:canonical_transaction, amount_cents: 127_50)
        expect {
          post :set_wise_transfer_return, params: { id: returned.id, wise_transfer_id: wise_transfer.id }
        }.to have_enqueued_mail(ReimbursementMailer, :wise_transfer_failed)
          .with(params: a_hash_including(reason: "Recipient bank rejected it", cancelled: true), args: [])

        expect(reversed).to eq([payout_holding.id])
      end
    end

    it "refuses to map an outgoing transaction as a return" do
      admin = create(:user, :make_admin)
      event = create(:event)
      wise_transfer = create_sent_wise_transfer(event:, user: admin)
      create_session(admin, verified: true)
      map_outgoing!(wise_transfer)
      other = create(:canonical_transaction, amount_cents: -5_00)

      post :set_wise_transfer_return, params: { id: other.id, wise_transfer_id: wise_transfer.id }

      expect(flash[:error]).to match(/incoming/)
      expect(other.reload.hcb_code).not_to eq(wise_transfer.hcb_code)
      expect(wise_transfer.reload).to be_deposited
    end

    it "refuses a transfer whose outgoing transaction hasn't been mapped" do
      admin = create(:user, :make_admin)
      event = create(:event)
      wise_transfer = create_sent_wise_transfer(event:, user: admin)
      create_session(admin, verified: true)
      returned = create(:canonical_transaction, amount_cents: 130_00)

      post :set_wise_transfer_return, params: { id: returned.id, wise_transfer_id: wise_transfer.id }

      expect(flash[:error]).to match(/outgoing transaction/)
      expect(wise_transfer.reload).to be_sent
    end
  end

  describe "#ach_start_approval" do
    render_views

    it "renders the ach transfer event's mission statement" do
      admin = create(:user, :make_admin)
      event = create(:event, :with_positive_balance, description: "Money wiring mission statement")
      ach_transfer = create(:ach_transfer, event:)

      create_session(admin, verified: true)

      get :ach_start_approval, params: { id: ach_transfer.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Money wiring mission statement")
    end
  end

  describe "#event_search" do
    it "returns JSON options the combobox can render" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)
      event = create(:event, name: "Hack Club HQ")

      get(:event_search, params: { q: "Hack Club HQ" }, format: :json)

      expect(response).to have_http_status(:ok)
      option = JSON.parse(response.body).find { |o| o["value"] == event.id.to_s }
      expect(option).to include("value" => event.id.to_s, "sublabel" => event.slug)
    end

    it "badges options with the ID for an admin, leaving the label plain" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)
      event = create(:event, name: "Hack Club HQ")

      get(:event_search, params: { q: "Hack Club HQ" }, format: :json)

      option = JSON.parse(response.body).find { |o| o["value"] == event.id.to_s }
      expect(option).to include("label" => "Hack Club HQ", "badge" => "ID: #{event.id}")
    end

    it "never shows a non-admin auditor the ID" do
      auditor = create(:user, :make_auditor)
      create_session(auditor, verified: true)
      event = create(:event, name: "Hack Club HQ")

      get(:event_search, params: { q: "Hack Club HQ" }, format: :json)

      option = JSON.parse(response.body).find { |o| o["value"] == event.id.to_s }
      expect(option).to include("label" => "Hack Club HQ", "badge" => nil)
    end

    it "paginates results without overlap across pages" do
      stub_const("ComboboxSearchable::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      3.times { |i| create(:event, name: "ysws #{i}") }

      get(:event_search, params: { q: "ysws", page: 1 }, format: :json)
      page1 = JSON.parse(response.body).map { |o| o["value"] }
      get(:event_search, params: { q: "ysws", page: 2 }, format: :json)
      page2 = JSON.parse(response.body).map { |o| o["value"] }

      expect(page1.size).to eq(2)
      expect(page2.size).to eq(1)
      expect(page1 & page2).to be_empty
    end

    it "clamps non-positive page numbers to the first page" do
      stub_const("ComboboxSearchable::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      3.times { |i| create(:event, name: "ysws #{i}") }

      get(:event_search, params: { q: "ysws", page: 0 }, format: :json)

      expect(JSON.parse(response.body).size).to eq(2)
    end
  end

  describe "#user_search" do
    it "gives an admin the name, the email beneath it and the ID as a badge" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)
      user = create(:user, full_name: "Jane Doe")

      get(:user_search, params: { q: "Jane Doe" }, format: :json)

      expect(response).to have_http_status(:ok)
      option = JSON.parse(response.body).find { |o| o["value"] == user.id.to_s }
      expect(option).to include("label" => "Jane Doe", "sublabel" => user.email, "badge" => "ID: #{user.id}")
    end

    it "never shows a non-admin auditor the ID" do
      auditor = create(:user, :make_auditor)
      create_session(auditor, verified: true)
      user = create(:user, full_name: "Jane Doe")

      get(:user_search, params: { q: "Jane Doe" }, format: :json)

      option = JSON.parse(response.body).find { |o| o["value"] == user.id.to_s }
      expect(option).to include("label" => "Jane Doe", "sublabel" => user.email, "badge" => nil)
    end

    # A label with leading or trailing space never equals the trimmed input, so
    # picking that user was undone the moment the field lost focus.
    it "labels nameless and space-padded users with trimmed text" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)
      nameless = create(:user, full_name: nil)
      padded = create(:user, full_name: "Jane Doe ")

      get(:user_search, format: :json)

      options = JSON.parse(response.body).index_by { |o| o["value"] }
      expect(options[nameless.id.to_s]).to include("label" => nameless.email, "sublabel" => nil)
      expect(options[padded.id.to_s]).to include("label" => "Jane Doe", "sublabel" => padded.email)
    end

    it "paginates results without overlap across pages" do
      stub_const("ComboboxSearchable::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      ["Searchable Personone", "Searchable Persontwo", "Searchable Personthree"].each do |name|
        create(:user, full_name: name)
      end

      get(:user_search, params: { q: "Searchable", page: 1 }, format: :json)
      page1 = JSON.parse(response.body).map { |o| o["value"] }
      get(:user_search, params: { q: "Searchable", page: 2 }, format: :json)
      page2 = JSON.parse(response.body).map { |o| o["value"] }

      expect(page1.size).to eq(2)
      expect(page1 & page2).to be_empty
    end
  end
end
