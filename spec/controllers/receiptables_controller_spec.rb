# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptablesController do
  include SessionSupport
  render_views

  let(:event) { create(:event) }
  let(:cpt) { create(:canonical_pending_transaction, amount_cents: -1234, raw_pending_stripe_transaction: create(:raw_pending_stripe_transaction)) }
  let(:hcb_code) { cpt.local_hcb_code }
  let(:base_params) { { receiptable_type: "HcbCode", receiptable_id: hcb_code.id } }
  let(:secret) { hcb_code.signed_id(expires_in: 2.weeks, purpose: :receipt_upload) }
  let(:details) do
    { date: "2026-01-15", merchant: "Stationery Shop", purpose: "Workshop supplies", signer_name: "Alex Example", confirmed: "1",
      items_attributes: [{ description: "Notebooks", quantity: 2, unit_amount_cents: 617 }]
}
  end

  before { create(:canonical_pending_event_mapping, canonical_pending_transaction: cpt, event:) }
  before { allow(CloudflareBrowserRun).to receive(:pdf).and_return("%PDF-1.4") }
  # The PDF is attached by a job; run it inline so these see the finished receipt.
  around { |example| perform_enqueued_jobs(only: LostReceipt::Statement::AttachPdfJob) { example.run } }

  describe "#mark_no_or_lost" do
    it "generates a statement using the receipt request link without claiming an authenticated signer" do
      post(:mark_no_or_lost, params: base_params.merge(s: secret, lost_receipt_statement: details))

      receipt = hcb_code.receipts.sole
      expect(receipt).to be_lost_receipt_statement
      expect(receipt.file.download).to start_with("%PDF")
      expect(CloudflareBrowserRun).to have_received(:pdf).with(a_string_including("Alex Example", "Receipt request link (not signed in)"))
      expect(receipt.user).to be_nil
      expect(hcb_code.reload).to be_no_or_lost_receipt
      expect(flash[:success]).to eq("Lost receipt statement submitted.")
      expect(response).to redirect_to(attach_receipt_hcb_code_path(hcb_code, s: secret))
    end

    it "does not file a second statement for the same transaction" do
      2.times { post(:mark_no_or_lost, params: base_params.merge(s: secret, lost_receipt_statement: details)) }

      expect(LostReceipt::Statement.count).to eq(1)
      expect(flash[:info]).to eq("This transaction already has a lost receipt statement.")
    end

    it "does not resolve the missing receipt without statement details" do
      expect {
        post(:mark_no_or_lost, params: base_params.merge(s: secret))
      }.not_to change(Receipt, :count)

      expect(hcb_code.reload).to be_missing_receipt
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "preserves entered details when confirmation is missing" do
      post(:mark_no_or_lost, params: base_params.merge(s: secret, lost_receipt_statement: details.merge(confirmed: "0")))

      expect(response).to have_http_status(:unprocessable_entity)
      expect(hcb_code.reload).to be_missing_receipt
      expect(response.body).to include("Stationery Shop", "Workshop supplies", "Notebooks", "must be accepted")
      expect(Nokogiri::HTML.fragment(response.body).at_css('input[name="s"]')["value"]).to eq(secret)
    end

    it "rejects oversized statements without attaching a receipt" do
      post(:mark_no_or_lost, params: base_params.merge(s: secret, lost_receipt_statement: details.merge(items_attributes: Array.new(51) { details[:items_attributes].first })))

      expect(response).to have_http_status(:unprocessable_entity)
      expect(hcb_code.reload).to be_missing_receipt
      expect(hcb_code.receipts).to be_empty
    end

    it "rejects malformed statement parameters" do
      ["invalid", [details]].each do |malformed|
        expect {
          post(:mark_no_or_lost, params: base_params.merge(s: secret, lost_receipt_statement: malformed))
        }.to raise_error(ActionController::ParameterMissing)
      end
      expect(hcb_code.reload).to be_missing_receipt
      expect(hcb_code.receipts).to be_empty
    end

    it "renders validation errors for malformed prices" do
      [{ unit_amount: true }, { unit_amount: false }, { unit_amount_cents: true }, { unit_amount_cents: false }].each do |price|
        item = { description: "Pens", quantity: 1 }.merge(price)
        post(:mark_no_or_lost, params: base_params.merge(s: secret, lost_receipt_statement: details.merge(items_attributes: [item])), as: :json, format: :html)

        expect(response).to have_http_status(:unprocessable_entity)
        # false casts to 0 on the integer column, so the total check is what rejects it.
        expect(response.body).to include(price.values.first ? "Unit amount cents is not a number" : "The items add up to $0.00")
        expect(hcb_code.receipts).to be_empty
      end
    end

    it "refuses a secret issued for a different transaction" do
      other_hcb_code = create(:canonical_pending_transaction).local_hcb_code
      other_secret = other_hcb_code.signed_id(expires_in: 2.weeks, purpose: :receipt_upload)

      post(:mark_no_or_lost, params: base_params.merge(s: other_secret, lost_receipt_statement: details))

      expect(hcb_code.receipts).to be_empty
      expect(other_hcb_code.receipts).to be_empty
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "refuses a secret issued for a different purpose" do
      status_secret = hcb_code.signed_id(expires_in: 2.weeks, purpose: :receipt_status)
      post(:mark_no_or_lost, params: base_params.merge(s: status_secret, lost_receipt_statement: details))

      expect(hcb_code.receipts).to be_empty
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "refuses an expired secret" do
      request_params = base_params.merge(s: secret, lost_receipt_statement: details)
      travel_to 3.weeks.from_now do
        post(:mark_no_or_lost, params: request_params)
      end

      expect(hcb_code.receipts).to be_empty
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "refuses a signed out user without a valid secret" do
      post(:mark_no_or_lost, params: base_params.merge(s: "invalid", lost_receipt_statement: details))

      expect(hcb_code.receipts).to be_empty
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "records the submitter and restores the missing receipt when the statement is deleted" do
      user = create(:user, full_name: "Alex Example")
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)
      hcb_code.no_or_lost_receipt!

      post(:mark_no_or_lost, params: base_params.merge(lost_receipt_statement: details.merge(submitter_id: create(:user).id)))

      receipt = hcb_code.receipts.sole
      expect(receipt.user).to eq(user)
      expect(user.receipts.lost_receipt_statement.sole).to eq(receipt)
      expect(hcb_code.reload).not_to be_missing_receipt
      expect(hcb_code).to be_no_or_lost_receipt
      expect(hcb_code.ledger_item.reload).to be_no_or_lost_receipt
      expect(response).to redirect_to(hcb_code_path(hcb_code))

      receipt.destroy!

      expect(hcb_code.reload).to be_missing_receipt
      expect(hcb_code.ledger_item.reload).to be_missing_receipt
      expect(hcb_code).not_to be_no_or_lost_receipt
      expect(hcb_code.ledger_item).not_to be_no_or_lost_receipt
      expect(user.receipts.lost_receipt_statement).to be_empty
    end

    it "returns to the page the form was opened from" do
      user = create(:user, full_name: "Alex Example")
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      request.headers["Referer"] = "http://test.host#{event_transactions_path(event)}"
      get(:lost_receipt, params: base_params)

      document = Nokogiri::HTML.fragment(response.body)
      expect(document.at_css("nav a.pop")["href"]).to eq("http://test.host#{event_transactions_path(event)}")
      continue = document.css("a").find { |link| link.text.include?("I still don't have it") }
      expect(Rack::Utils.parse_query(URI(continue["href"]).query)).to include("continue" => "1", "return_to" => "http://test.host#{event_transactions_path(event)}")
    end

    it "preserves the originating popover through the statement form" do
      user = create(:user, full_name: "Alex Example")
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      page_with_popover = event_transactions_path(event, popover: hcb_code_path(hcb_code))
      get(:lost_receipt, params: base_params.merge(return_to: page_with_popover, continue: 1))
      return_to = Nokogiri::HTML.fragment(response.body).at_css('input[name="return_to"]')["value"]
      expect(return_to).to eq(page_with_popover)

      post(:mark_no_or_lost, params: base_params.merge(return_to:, lost_receipt_statement: details))

      expect(hcb_code.reload).to be_no_or_lost_receipt
      expect(hcb_code.receipts.sole).to be_lost_receipt_statement
      expect(response).to redirect_to(page_with_popover)
    end

    it "rejects a signature that isn't the signed-in user's name" do
      user = create(:user, full_name: "Jordan Rivera")
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      post(:mark_no_or_lost, params: base_params.merge(lost_receipt_statement: details))
      expect(response).to have_http_status(:unprocessable_content)
      expect(hcb_code.receipts).to be_empty

      post(:mark_no_or_lost, params: base_params.merge(lost_receipt_statement: details.merge(signer_name: " jordan  rivera ")))
      expect(hcb_code.receipts.sole).to be_lost_receipt_statement
    end

    it "ignores an external return_to" do
      user = create(:user, full_name: "Alex Example")
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      post(:mark_no_or_lost, params: base_params.merge(return_to: "https://evil.example.com", lost_receipt_statement: details))

      expect(response).to redirect_to(hcb_code_path(hcb_code))
    end

    it "sends someone who found their receipt to the transaction, not back to where they came from" do
      user = create(:user, full_name: "Alex Example")
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      get(:lost_receipt, params: base_params.merge(return_to: event_transactions_path(event)))

      found = Nokogiri::HTML.fragment(response.body).at_xpath('.//a[contains(., "I found it")]')
      expect(URI(found["href"]).path).to eq(hcb_code_path(hcb_code))
    end

    it "ignores a javascript: return_to" do
      user = create(:user, full_name: "Alex Example")
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      get(:lost_receipt, params: base_params.merge(return_to: "javascript://test.host/%0aalert(1)"))

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("javascript:")
    end

    it "refuses receiptables that can't be marked no/lost" do
      create_session(create(:user, :make_admin), verified: true)
      expense = create(:reimbursement_expense)

      expect do
        get(:lost_receipt, params: { receiptable_type: "Reimbursement::Expense", receiptable_id: expense.id })
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "refuses a signed in user who isn't on the organization" do
      create_session(create(:user, full_name: "Alex Example"), verified: true)
      post(:mark_no_or_lost, params: base_params.merge(lost_receipt_statement: details))

      expect(hcb_code.receipts).to be_empty
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "attaches ledger statements to the underlying transaction" do
      user = create(:user, full_name: "Alex Example")
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      post(:mark_no_or_lost, params: { receiptable_type: "Ledger::Item", receiptable_id: hcb_code.ledger_item.id, lost_receipt_statement: details })

      expect(hcb_code.receipts.sole).to be_lost_receipt_statement
      expect(hcb_code.ledger_item.reload).not_to be_missing_receipt
    end
  end

  describe "#lost_receipt" do
    it "first suggests ways to find the receipt" do
      get(:lost_receipt, params: base_params.merge(s: secret))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Have you tried these?", "help.hcb.hackclub.com/en/articles/15410231")
      expect(Nokogiri::HTML.fragment(response.body).at_css("form")).to be_nil
    end

    it "opens a prefilled statement form from the signed email link" do
      get(:lost_receipt, params: base_params.merge(s: secret, continue: 1))

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML.fragment(response.body)
      expect(document.at_css('input[name="lost_receipt_statement[date]"]')["value"]).to eq(hcb_code.date.iso8601)
      expect(document.at_css('input[name="lost_receipt_statement[merchant]"]')["value"]).to eq(hcb_code.memo)
      expect(document.at_css('input[name="lost_receipt_statement[items_attributes][0][quantity]"]')["value"]).to eq("1")
      expect(document.at_css('input[name="lost_receipt_statement[items_attributes][0][unit_amount]"]')).to be_present
      expect(document.at_css('input[name="lost_receipt_statement[confirmed]"][required]')).to be_present
      expect(document.at_css('input[type="file"]')).to be_nil
    end

    it "refuses to open the form without authorization" do
      get(:lost_receipt, params: base_params)

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end
  end

  # Receipts are moving onto ledger items (#14106), so the upload form can post
  # the ledger item as the receiptable while still carrying the HCB code's secret.
  describe "#mark_no_or_lost with a Ledger::Item receiptable" do
    let(:ledger_item) { hcb_code.reload.ledger_item }

    it "marks both sides using the HCB code's secret, without signing in" do
      post(:mark_no_or_lost, params: { receiptable_type: "Ledger::Item", receiptable_id: ledger_item.id, s: secret, lost_receipt_statement: details })

      expect(ledger_item.reload).to be_no_or_lost_receipt
      expect(hcb_code.reload).to be_no_or_lost_receipt
      expect(response).to redirect_to(attach_receipt_hcb_code_path(hcb_code, s: secret))
    end

    it "refuses a secret issued for a different transaction" do
      other_secret = create(:canonical_pending_transaction).local_hcb_code.signed_id(expires_in: 2.weeks, purpose: :receipt_upload)

      post(:mark_no_or_lost, params: { receiptable_type: "Ledger::Item", receiptable_id: ledger_item.id, s: other_secret, lost_receipt_statement: details })

      expect(ledger_item.reload).not_to be_no_or_lost_receipt
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end
  end

  context "models including Receiptable" do
    it "are explicitly registered" do
      Rails.application.eager_load!

      ApplicationRecord.descendants
                       .filter { _1.include?(Receiptable) }
                       .each do |klass|
        expect(ReceiptablesController::RECEIPTABLE_TYPE_MAP).to have_key(klass.to_s)
      end
    end
  end
end
