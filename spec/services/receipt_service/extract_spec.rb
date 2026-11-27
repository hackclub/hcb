# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptService::Extract do
  def build_receipt(**attributes)
    user = create(:user)
    Receipt.new(upload_method: :api, user:, textual_content: "some receipt text", **attributes).tap do |receipt|
      receipt.file.attach(
        io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
        filename: "receipt.png",
        content_type: "image/png"
      )
      receipt.save!
    end
  end

  let(:extracted_data) do
    {
      transaction_memo: "☕ Coffee from Cafe",
      total_amount_cents: 500,
      currency: "usd"
    }
  end

  let(:ai_response_body) do
    {
      choices: [
        {
          message: {
            content: extracted_data.to_json
          }
        }
      ]
    }.to_json
  end

  before do
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 200, body: ai_response_body, headers: { "Content-Type" => "application/json" })
  end

  it "persists the extracted data onto the receipt" do
    receipt = build_receipt

    described_class.new(receipt:).run!

    receipt.reload
    expect(receipt.data_extracted?).to be(true)
    expect(receipt.suggested_memo).to eq("☕ Coffee from Cafe")
  end

  describe "the AI memo suggestion" do
    let(:item_target) { ActionView::RecordIdentifier.dom_id(ledger_item, :ai_memo) }

    context "on a receipt attached to a ledger item with an HCB code" do
      let(:ledger_item) { create(:ledger_item) }

      before { create(:hcb_code, ledger_item:) }

      it "broadcasts to both headings over the item's stream" do
        receipt = build_receipt(receiptable: ledger_item)

        expect(Turbo::StreamsChannel).to receive(:broadcast_action_later_to)
          .with([ledger_item, "ai_memo"], hash_including(target: item_target, partial: "ledger/items/memo/ai"))
        expect(Turbo::StreamsChannel).to receive(:broadcast_action_later_to)
          .with([ledger_item, "ai_memo"], hash_including(target: "ai_memo", partial: "hcb_codes/memo/ai"))

        described_class.new(receipt:).run!
      end

      # Broadcasting through the HcbCode model made Turbo add an `hcb_code`
      # local, which the ledger item partial's strict `(item:)` locals
      # rejected, so the broadcast job raised ActionView::Template::Error.
      it "renders both partials without error" do
        receipt = build_receipt(receiptable: ledger_item)

        expect {
          perform_enqueued_jobs(only: Turbo::Streams::ActionBroadcastJob) do
            described_class.new(receipt:).run!
          end
        }.not_to raise_error
      end
    end

    context "on a receipt attached to a ledger item with no HCB code" do
      let(:ledger_item) { create(:ledger_item) }

      it "broadcasts to the item's heading only" do
        receipt = build_receipt(receiptable: ledger_item)

        expect(Turbo::StreamsChannel).to receive(:broadcast_action_later_to)
          .with([ledger_item, "ai_memo"], hash_including(target: item_target)).once

        described_class.new(receipt:).run!
      end
    end

    it "is not broadcast for a receipt that isn't on a ledger item" do
      receipt = build_receipt

      expect(Turbo::StreamsChannel).not_to receive(:broadcast_action_later_to)

      described_class.new(receipt:).run!
    end
  end

  # The OpenAI request above is slow enough that a user can delete the
  # receipt (or its file) from under the job while it's in flight. Before the
  # fix, the final `@receipt.update!` would re-validate `attached: true`
  # against the now-gone attachment and raise ActiveRecord::RecordInvalid
  # ("File can't be blank") instead of just no-oping.
  it "does not raise when the receipt is deleted while the extraction request is in flight" do
    receipt = build_receipt

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return do |_request|
        # simulate a separate request (e.g. the user deleting the receipt from
        # the UI) racing the job, rather than mutating the job's own in-memory
        # object directly
        Receipt.find(receipt.id).destroy!
        { status: 200, body: ai_response_body, headers: { "Content-Type" => "application/json" } }
      end

    expect { described_class.new(receipt:).run! }.not_to raise_error
    expect(Receipt.exists?(receipt.id)).to be(false)
  end
end
