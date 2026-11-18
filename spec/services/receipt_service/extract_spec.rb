# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptService::Extract do
  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

  let(:user) { create(:user) }

  def build_receipt(io: File.open(Rails.root.join("spec/fixtures/files/receipt.png"), "rb"), filename: "receipt.png", content_type: "image/png", **attributes)
    Receipt.new(upload_method: :api, user:, **attributes).tap do |receipt|
      receipt.file.attach(io:, filename:, content_type:)
      receipt.save!
    end
  end

  def pdf(text = nil)
    io = StringIO.new
    surface = Cairo::PDFSurface.new(io, 300, 400)
    context = Cairo::Context.new(surface)
    if text
      context.move_to(20, 50)
      context.show_text(text)
    end
    context.show_page
    surface.finish
    StringIO.new(io.string)
  end

  let(:extracted_data) do
    {
      subtotal_amount_cents: 450,
      total_amount_cents: 500,
      currency: "usd",
      card_last_four: "4242",
      date: "2026-11-02",
      merchant_url: "https://cafe.example",
      merchant_name: "Cafe",
      merchant_zip_code: "05401",
      transaction_memo: "☕ Coffee from Cafe"
    }
  end

  def ai_response(data)
    { status: 200, body: { choices: [{ message: { content: data.to_json } }] }.to_json, headers: { "Content-Type" => "application/json" } }
  end

  def sent_content
    content = nil
    expect(a_request(:post, openai_url).with { |req| content = JSON.parse(req.body); true }).to have_been_made.once
    content
  end

  def user_parts
    sent_content.dig("messages", 1, "content")
  end

  before do
    stub_request(:post, openai_url).to_return { ai_response(extracted_data) }
  end

  it "sends the image of an image receipt with a JSON schema response format and persists the result" do
    receipt = build_receipt(textual_content: "some receipt text")

    expect(described_class.new(receipt:).run!).to eq(receipt)

    body = sent_content
    expect(body.dig("response_format", "type")).to eq("json_schema")
    expect(body.dig("response_format", "json_schema", "strict")).to be(true)
    parts = body.dig("messages", 1, "content")
    expect(parts.find { |p| p["type"] == "image_url" }.dig("image_url", "url")).to start_with("data:image/png;base64,")
    expect(parts.map { |p| p["text"] }.join).to include("some receipt text")

    receipt.reload
    expect(receipt).to have_attributes(
      data_extracted: true,
      suggested_memo: "☕ Coffee from Cafe",
      extracted_subtotal_amount_cents: 450,
      extracted_total_amount_cents: 500,
      extracted_currency: "USD",
      extracted_card_last4: "4242",
      extracted_merchant_name: "Cafe",
      extracted_merchant_url: "https://cafe.example",
      extracted_merchant_zip_code: "05401"
    )
    expect(receipt.extracted_date.to_date).to eq(Date.new(2026, 11, 2))
  end

  it "discards values that fail validation" do
    extracted_data.merge!(subtotal_amount_cents: -1, total_amount_cents: 12.5, currency: "dollars", card_last_four: "x4242", date: "2026-02-30", merchant_name: "")

    receipt = build_receipt
    described_class.new(receipt:).run!

    expect(receipt.reload).to have_attributes(
      data_extracted: true,
      extracted_subtotal_amount_cents: nil,
      extracted_total_amount_cents: nil,
      extracted_currency: nil,
      extracted_card_last4: nil,
      extracted_date: nil,
      extracted_merchant_name: nil
    )
  end

  it "sends only the text layer of a PDF that has one" do
    receipt = build_receipt(io: pdf("Cafe receipt total $5.00 card ending 4242"), filename: "receipt.pdf", content_type: "application/pdf")

    described_class.new(receipt:).run!

    parts = user_parts
    expect(parts.map { |p| p["type"] }).not_to include("image_url")
    expect(parts.map { |p| p["text"] }.join).to include("total $5.00")
    expect(receipt.reload.data_extracted).to be(true)
  end

  it "renders a scanned PDF's first page as an image" do
    receipt = build_receipt(io: pdf, filename: "scan.pdf", content_type: "application/pdf")

    described_class.new(receipt:).run!

    expect(user_parts.find { |p| p["type"] == "image_url" }.dig("image_url", "url")).to start_with("data:image/png;base64,")
  end

  it "marks a receipt with no text and no sendable image as extracted without calling the API" do
    receipt = build_receipt(io: StringIO.new("a,b\n1,2\n"), filename: "receipt.csv", content_type: "text/csv")

    expect(described_class.new(receipt:).run!).to be_nil

    expect(a_request(:post, openai_url)).not_to have_been_made
    expect(receipt.reload.data_extracted).to be(true)
  end

  it "rate limits users with more than 50 extractions in the last hour" do
    receipt = build_receipt
    rows = Array.new(51) { { user_id: user.id, data_extracted: true, created_at: 30.minutes.ago, updated_at: Time.current } }
    Receipt.insert_all(rows)

    expect(described_class.new(receipt:).run!).to be_nil
    expect(a_request(:post, openai_url)).not_to have_been_made

    Receipt.where(user:, data_extracted: true).update_all(created_at: 2.hours.ago)
    described_class.new(receipt:).run!
    expect(a_request(:post, openai_url)).to have_been_made.once
  end

  it "leaves the receipt unextracted when the API fails" do
    stub_request(:post, openai_url).to_return(status: 500)
    receipt = build_receipt

    expect(described_class.new(receipt:).run!).to be_nil
    expect(receipt.reload.data_extracted).to be(false)
  end

  # The OpenAI request above is slow enough that a user can delete the
  # receipt (or its file) from under the job while it's in flight. Before the
  # fix, the final `@receipt.update!` would re-validate `attached: true`
  # against the now-gone attachment and raise ActiveRecord::RecordInvalid
  # ("File can't be blank") instead of just no-oping.
  it "does not raise when the receipt is deleted while the extraction request is in flight" do
    receipt = build_receipt

    stub_request(:post, openai_url)
      .to_return do |_request|
        # simulate a separate request (e.g. the user deleting the receipt from
        # the UI) racing the job, rather than mutating the job's own in-memory
        # object directly
        Receipt.find(receipt.id).destroy!
        ai_response(extracted_data)
      end

    expect { described_class.new(receipt:).run! }.not_to raise_error
    expect(Receipt.exists?(receipt.id)).to be(false)
  end
end
