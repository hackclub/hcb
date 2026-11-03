# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExtractionController do
  include SessionSupport

  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

  def stub_openai(extracted)
    stub_request(:post, openai_url)
      .to_return(status: 200, body: { choices: [{ message: { content: extracted.to_json } }] }.to_json, headers: { "Content-Type" => "application/json" })
  end

  describe "#invoice" do
    it "doesn't send files to OpenAI for signed-out requests" do
      post :invoice, params: { file: fixture_file_upload("invoice.pdf", "application/pdf") }

      expect(response).to have_http_status(:redirect)
      expect(a_request(:post, openai_url)).not_to have_been_made
    end

    it "rejects files that aren't PDFs or images without calling OpenAI" do
      create_session(create(:user), verified: true)

      post :invoice, params: { file: fixture_file_upload("attachment1.txt", "text/plain") }

      expect(response).to have_http_status(:unprocessable_content)
      expect(a_request(:post, openai_url)).not_to have_been_made
    end

    # The total fills an <input type="number">, which blanks values like "1,234.56".
    it "returns totals of $1,000 or more without a thousands separator" do
      create_session(create(:user), verified: true)
      stub_openai(seller_name: "Raviga Capital", routing_number: nil, invoice_items: [{ label: "Servers", amount: "$1,000.00" }, { label: "Support", amount: 234.56 }])

      post :invoice, params: { file: fixture_file_upload("invoice.pdf", "application/pdf") }

      expect(response.parsed_body).to include("total" => "1234.56", "seller_name" => "Raviga Capital", "routing_number" => nil)
    end
  end
end
