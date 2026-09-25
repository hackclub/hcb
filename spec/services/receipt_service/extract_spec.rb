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
