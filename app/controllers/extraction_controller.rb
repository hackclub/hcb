# frozen_string_literal: true

class ExtractionController < ApplicationController
  skip_after_action :verify_authorized, only: [:invoice]

  def invoice
    textual_content_source = if params[:file].content_type == "application/pdf"
                               :pdf_text
                             elsif params[:file].content_type.starts_with?("image")
                               :tesseract_ocr_text
                             else
                               return nil
                             end

    @file = params[:file].tempfile

    text = self.send(textual_content_source) || ""

    keys = ["recipient_name", "recipient_email", "account_number", "routing_number", "bank_name", "recipient_address_line_1", "recipient_address_line_2", "recipient_address_state_code", "recipient_address_zip", "recipient_address_city", "seller_name", "seller_email", "seller_address_line_1", "seller_address_line_2", "seller_address_state_code", "seller_address_zip", "seller_address_city"]

    prompt = <<~PROMPT
      You are a helpful assistant that extracts important features about the entity that the invoice is from.

      You must extract the following features in JSON format:

      #{keys.join(" \n")}

      If you can't extract a feature, or if you can't find any features, return null for the respective keys.

      Additionally, return an array of invoice items (invoice_items as the key) each in the following JSON format:

      label
      amount#{' '}
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
                             },
                             {
                               role: "user",
                               content: text.truncate(80_000, omission: "...#{text.last(40_000)}")
                             }
                           ],
                           response_format: {
                             type: "json_object"
                           }
                         })

    ai_response = response.body.dig("choices", 0, "message", "content")

    extracted = JSON.parse(ai_response)

    total = ApplicationController.helpers.render_money_amount(Monetize.parse(extracted["invoice_items"].sum { |i| Monetize.parse(i["amount"]).amount }))

    json = {
      total:
    }

    keys.each do |key|
      json[key] = extracted[key]
    end

    render json:
  end

  private

  def pdf_text
    doc = Poppler::Document.new(File.read(@file))

    doc.pages.map(&:text).join(" ")
  end

  def tesseract_ocr_text
    words = ::RTesseract.new(ImageProcessing::MiniMagick.source(@file.path).convert!("png").path).to_box
    words = words.select { |w| w[:confidence] > 85 }
    words = words.map { |w| w[:word] }
    text = words.join(" ")
    text.length > 50 ? text : nil
  end

end
