# frozen_string_literal: true

require "rails_helper"

RSpec.describe Blazer::AiQueryGenerator do
  it "returns parsed name and statement from OpenAI response" do
    stubs = Faraday::Adapter::Test::Stubs.new

    stubs.post("/v1/chat/completions") do
      [
        200,
        { "Content-Type" => "application/json" },
        {
          choices: [
            {
              message: {
                content: { name: "Donation totals", statement: "SELECT 1" }.to_json
              }
            }
          ]
        }
      ]
    end

    conn = Faraday.new do |f|
      f.request :json
      f.response :json
      f.adapter :test, stubs
    end

    result = described_class.new(prompt: "Show donation totals", conn:).run!

    expect(result[:name]).to eq("Donation totals")
    expect(result[:statement]).to eq("SELECT 1")
  end
end
