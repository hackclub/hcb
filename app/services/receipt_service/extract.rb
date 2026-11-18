# frozen_string_literal: true

module ReceiptService
  class Extract
    MODEL = "gpt-5.6-luna"
    # OpenAI accepts png, jpeg, webp and non-animated gif images, up to 20MB.
    IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
    MAX_IMAGE_BYTES = 20.megabytes
    # a PDF text layer shorter than this is treated as scanned
    MIN_PDF_TEXT_LENGTH = 20

    PROMPT = <<~PROMPT
      You are a helpful assistant that extracts important features from receipts. You may be given an image of the receipt, its text, or both. Extract:

      subtotal_amount_cents: subtotal before tax and tip, as integer cents
      total_amount_cents: the final amount charged to the card, including tax, tip and fees, as integer cents (e.g. $12.34 is 1234). If the receipt shows several totals, use the one actually paid.
      currency: ISO 4217 currency code, e.g. "USD"
      card_last_four: the last four digits of the payment card, exactly four digits, or null if not shown
      date: the purchase date in YYYY-MM-DD. If the year is missing, infer the most recent year that does not put the date after the upload date.
      merchant_url: URL for merchant's primary website including https, if available
      merchant_name: short recognizable concise common name without identifiers or order numbers
      merchant_zip_code: if available
      transaction_memo: a good memo includes quantity (if it's more than one), the item(s) purchased, and the merchant. pretend someone will use the memos in the sentence, "In this transaction, I purchased (a) <memo>" where <memo> is what you generate. some good examples are "🏷️ 5,000 Event stickers from StickerMule", "💧 Office water supply from Culligan", "🔌 USB-C cable for MacBook", "💾 10 Airtable team seats for December", and "🚕 Uber to SFO Airport". avoid generic quantifiers like "multiple", "many", or "assorted", using improper capitalization, unnecessarily verbose descriptions, addresses, and transaction/merchant/order IDs. Ensure memos are less than 60 characters.

      If you can't extract a feature, return null for it.
    PROMPT

    FIELDS = {
      subtotal_amount_cents: "integer",
      total_amount_cents: "integer",
      currency: "string",
      card_last_four: "string",
      date: "string",
      merchant_url: "string",
      merchant_name: "string",
      merchant_zip_code: "string",
      transaction_memo: "string",
    }.freeze

    RESPONSE_FORMAT = {
      type: "json_schema",
      json_schema: {
        name: "receipt",
        strict: true,
        schema: {
          type: "object",
          additionalProperties: false,
          required: FIELDS.keys,
          properties: FIELDS.transform_values { |type| { type: [type, "null"] } }
        }
      }
    }.freeze

    def initialize(receipt:)
      @receipt = receipt.reload
    end

    def run!
      return @receipt if @receipt.data_extracted?

      # this line acts as a rate limit of sort.
      # see https://github.com/hackclub/hcb/issues/7167.
      return if @receipt.user.receipts.where(created_at: 1.hour.ago.., data_extracted: true).count > 50 ||
                (@receipt.receiptable.present? && @receipt.receiptable.receipts.where(data_extracted: true).count > 5)

      text = textual_content
      image = image_data_url(text)
      if text.blank? && image.nil?
        @receipt.update(data_extracted: true)
        return
      end

      extracted = request_extraction(text, image)
      return if extracted.nil?

      # the OpenAI request above can take a while; the receipt (or its file)
      # may have been deleted in the meantime, e.g. the user removed it from
      # the receipt bin. re-check freshness before persisting to avoid a
      # RecordInvalid on the "file can't be blank" validation.
      @receipt = Receipt.find_by(id: @receipt.id)
      return if @receipt.nil? || !@receipt.file.attached?

      @receipt.update!(
        suggested_memo: extracted["transaction_memo"].presence,
        extracted_subtotal_amount_cents: cents(extracted["subtotal_amount_cents"]),
        extracted_total_amount_cents: cents(extracted["total_amount_cents"]),
        extracted_currency: extracted["currency"]&.strip&.upcase&.then { |c| c if c.match?(/\A[A-Z]{3}\z/) },
        extracted_card_last4: extracted["card_last_four"]&.strip&.then { |l| l if l.match?(/\A\d{4}\z/) },
        extracted_date: begin
          extracted["date"].presence && Date.iso8601(extracted["date"])
        rescue Date::Error
          nil
        end,
        extracted_merchant_name: extracted["merchant_name"].presence,
        extracted_merchant_url: extracted["merchant_url"].presence,
        extracted_merchant_zip_code: extracted["merchant_zip_code"].presence,
        data_extracted: true
      )

      if (hcb_code = @receipt.hcb_code).present?
        hcb_code.broadcast_action_later_to(
          [hcb_code, "ai_memo"],
          action: :replace,
          target: "ai_memo",
          partial: "hcb_codes/memo/ai",
          locals: { hcb_code: }
        )

        # The ledger item's heading shows the same icon under its own target, so
        # whichever page is open picks the suggestion up. This goes through
        # Turbo::StreamsChannel rather than the model so Turbo doesn't inject an
        # `hcb_code` local, which the partial's strict locals would reject.
        if (ledger_item = hcb_code.ledger_item).present?
          Turbo::StreamsChannel.broadcast_action_later_to(
            [hcb_code, "ai_memo"],
            action: :replace,
            target: ActionView::RecordIdentifier.dom_id(ledger_item, :ai_memo),
            partial: "ledger/items/memo/ai",
            locals: { item: ledger_item }
          )
        end
      end

      unless @receipt.receiptable
        @receipt.broadcast_replace_to(
          [@receipt.user, :receipt_bin],
          target: nil,
          targets: "div[data-extracted-data-for='#{@receipt.id}']",
          partial: "receipts/extracted",
          locals: { receipt: @receipt, current_user: @receipt.user }
        )
      end

      @receipt
    end

    private

    # Tesseract is slow and optional, so images never trigger OCR here; the model reads the image itself.
    def textual_content
      return @receipt.textual_content if @receipt.textual_content || @receipt.file.content_type != "application/pdf"

      @receipt.extract_textual_content![:text]
    end

    def image_data_url(text)
      content_type = @receipt.file.content_type
      bytes, type = if content_type == "application/pdf"
                      [render_first_pdf_page, "image/png"] if text.to_s.squish.length < MIN_PDF_TEXT_LENGTH
                    elsif content_type.start_with?("image/")
                      downscaled_image || ([@receipt.file.download, content_type] if content_type.in?(IMAGE_CONTENT_TYPES))
                    end
      return if bytes.nil? || bytes.bytesize > MAX_IMAGE_BYTES

      "data:#{type};base64,#{Base64.strict_encode64(bytes)}"
    rescue => e
      Rails.error.report(e, context: { receipt_id: @receipt.id })
      nil
    end

    def downscaled_image
      variant = @receipt.file.variant(Receipt::PREPROCESSED_SIZES.first.to_sym).processed
      [variant.download, variant.content_type] if variant.content_type.in?(IMAGE_CONTENT_TYPES)
    rescue => e
      # ImageMagick can fail on some files; the caller falls back to the original bytes.
      Rails.error.report(e, context: { receipt_id: @receipt.id })
      nil
    end

    def render_first_pdf_page
      page = Poppler::Document.new(@receipt.file.download).pages.first
      return if page.nil?

      width, height = page.size
      scale = [2048.0 / [width, height].max, 4].min
      surface = Cairo::ImageSurface.new(:rgb24, (width * scale).ceil, (height * scale).ceil)
      context = Cairo::Context.new(surface)
      context.set_source_rgb(1, 1, 1)
      context.paint
      context.scale(scale, scale)
      page.render(context)
      StringIO.new.tap { |io| surface.write_to_png(io) }.string
    end

    def request_extraction(text, image)
      content = [{ type: "text", text: "This receipt was uploaded on #{@receipt.created_at.to_date.iso8601}." }]
      content << { type: "text", text: "Receipt text:\n#{text.truncate(80_000, omission: "...#{text.last(40_000)}")}" } if text.present?
      content << { type: "image_url", image_url: { url: image, detail: "high" } } if image

      conn = Faraday.new url: "https://api.openai.com" do |f|
        f.request :json
        f.request :authorization, "Bearer", -> { Credentials.fetch(:OPENAI, :RECEIPT_EXTRACTION) }
        f.response :raise_error
        f.response :json
      end

      response = conn.post("/v1/chat/completions", {
                             model: MODEL,
                             messages: [
                               { role: "system", content: PROMPT },
                               { role: "user", content: }
                             ],
                             response_format: RESPONSE_FORMAT
                           })

      # content is nil when the model refuses
      parsed = JSON.parse(response.body.dig("choices", 0, "message", "content") || "null")
      parsed if parsed.is_a?(Hash)
    rescue Faraday::Error, JSON::ParserError => e
      # leave data_extracted false so a later run can retry
      Rails.error.report(e, context: { receipt_id: @receipt.id })
      nil
    end

    def cents(value)
      value if value.is_a?(Integer) && value >= 0
    end

  end
end
