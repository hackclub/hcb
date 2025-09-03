# frozen_string_literal: true

module HcbCodeService
  module Generate
    class SuggestedTags
      include StripeAuthorizationsHelper

      def initialize(hcb_code:, event:)
        @hcb_code = hcb_code
        @event = event
      end

      def run!
        return unless @event && @hcb_code&.stripe_card?
        # don't suggest tags for transactions already with tags or tag suggestions
        return if @hcb_code.tags.filter { |tag| tag.event == @event }.any?

        prompt = <<~PROMPT
          You are a helpful assistant that tags transactions from a list of tags based on the merchant, type of merchant, and the memo. You should return the ID of the tag you think is must applicable; if you are not 100% confident that a tag matches, return null.

          Here is the information about the transaction:

          Merchant: #{humanized_merchant_name @hcb_code.stripe_merchant}
          Merchant Category: #{@hcb_code.stripe_merchant["category"].humanize.capitalize}
          Memo: #{@hcb_code.memo}

          Here are the available tags, the ID is in square brackets:

          #{@event.tags.map { |tag| "#{tag.label} [#{tag.id}]" }.join("\n")}

          Respond with only the ID of a tag if you are confident it is appropriate, otherwise respond with null.
        PROMPT

        conn = Faraday.new url: "https://api.openai.com" do |f|
          f.request :json
          f.request :authorization, "Bearer", -> { Credentials.fetch(:OPENAI_API_KEY) }
          f.response :raise_error
          f.response :json
        end

        response = conn.post("/v1/chat/completions", {
                               model: "gpt-4o",
                               messages: [
                                 {
                                   role: "system",
                                   content: prompt
                                 }
                               ]
                             })

        id = response.body.dig("choices", 0, "message", "content")&.delete("^0-9")

        if tag = Tag.find_by(id:, event: @event)
          HcbCode::Tag::Suggestion.create(tag:, hcb_code: @hcb_code)
        end
      end


    end
  end
end
