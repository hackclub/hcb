# frozen_string_literal: true

module ReceiptService
  class Extract
    def initialize(receipt:)
      @receipt = receipt.reload
    end

    def run!
      return @receipt if @receipt.data_extracted?

      # this line acts as a rate limit of sort.
      # see https://github.com/hackclub/hcb/issues/7167.
      return if @receipt.user.receipts.where(created_at: 1.hour.ago, data_extracted: true).count > 50 ||
                (@receipt.receiptable.present? && @receipt.receiptable.receipts.where(data_extracted: true).count > 5)

      @textual_content = @receipt.textual_content || @receipt.extract_textual_content!
      if @textual_content.nil?
        @receipt.update(data_extracted: true)
        return
      end

      prompt = <<~PROMPT
        You are a helpful assistant that extracts important features from receipts. You must extract the following features in JSON format:

        subtotal_amount_cents
        total_amount_cents // the amount likely to be charged to a credit card
        card_last_four
        date // in the format of YYYY-MM-DD
        merchant_url // URL for merchant's primary website including https, if available
        merchant_name // short recognizable concise common name without identifiers or order numbers
        merchant_zip_code // if available
        transaction_memo // a good memo includes quantity (if it's more than one), the item(s) purchased, and the merchant. pretend someone will use the memos in the sentence, "In this transaction, I purchased (a) <memo>" where <memo> is what you generate. some good examples are "🏷️ 5,000 Event stickers from StickerMule", "💧 Office water supply from Culligan", "🔌 USB-C cable for MacBook", "💾 10 Airtable team seats for December", and "🚕 Uber to SFO Airport". avoid generic quantifiers like "multiple", "many", or "assorted", using improper capitalization, unnecessarily verbose descriptions, addresses, and transaction/merchant/order IDs. Ensure memos are less than 60 characters.

        If you can't extract a feature, or if you can't find any features, return null for the respective keys.
      PROMPT

      conn = Faraday.new url: "https://api.openai.com" do |f|
        f.request :json
        f.request :authorization, "Bearer", -> { Rails.application.credentials.openai.api_key }
        f.response :raise_error
        f.response :json
      end

      response = conn.post("/v1/chat/completions", {
                             model: "gpt-4o",
                             messages: [
                               {
                                 role: "system",
                                 content: prompt
                               },
                               {
                                 role: "user",
                                 content: @textual_content
                               }
                             ]
                           })

      ai_response = response.body.dig("choices", 0, "message", "content")
      if ai_response.starts_with?("```json") && ai_response.ends_with?("```")
        ai_response = ai_response[7..-4]
      end

      extracted = begin
        JSON.parse(ai_response).yield_self { |r| r.is_a?(Array) ? r.first : r }.with_indifferent_access # JSON given by ChatGPT, may fail. The `yield_self` handles ChatGPT returning an array.
      rescue JSON::ParserError
        nil
      end

      return if extracted.nil?

      extracted[:textual_content] = @receipt.textual_content

      data = OpenStruct.new(extracted) # Protection against missing keys

      @receipt.update!(
        suggested_memo: data.transaction_memo,
        extracted_subtotal_amount_cents: data.subtotal_amount_cents&.to_i,
        extracted_total_amount_cents: data.total_amount_cents&.to_i,
        extracted_card_last4: data.card_last_four,
        extracted_date: data.date&.to_date,
        extracted_merchant_name: data.merchant_name,
        extracted_merchant_url: data.merchant_url,
        extracted_merchant_zip_code: data.merchant_zip_code,
        data_extracted: true
      )


      if @receipt.receiptable_type == "HcbCode"
        hcb_code = @receipt.receiptable
        hcb_code.broadcast_action_later_to(
          [hcb_code, "ai_memo"],
          action: :replace,
          target: "ai_memo",
          partial: "hcb_codes/ai_memo",
          locals: { hcb_code: }
        )
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

  end
end
