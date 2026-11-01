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

    generator = described_class.new(prompt: "Show donation totals", conn:)
    allow(generator).to receive(:validate_statement).and_return(nil)

    result = generator.run!

    expect(result[:name]).to eq("Donation totals")
    expect(result[:statement]).to eq("SELECT 1")
  end

  it "retries when query execution fails and returns corrected SQL" do
    stubs = Faraday::Adapter::Test::Stubs.new
    request_payloads = []

    stubs.post("/v1/chat/completions") do |env|
      request_payloads << env.body
      [
        200,
        { "Content-Type" => "application/json" },
        {
          choices: [
            {
              message: {
                content: { name: "Donation totals", statement: "SELECT broken" }.to_json
              }
            }
          ]
        }
      ]
    end

    stubs.post("/v1/chat/completions") do |env|
      request_payloads << env.body
      [
        200,
        { "Content-Type" => "application/json" },
        {
          choices: [
            {
              message: {
                content: { name: "Donation totals fixed", statement: "SELECT 1" }.to_json
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

    generator = described_class.new(prompt: "Show donation totals", conn:)
    allow(generator).to receive(:validate_statement).with("SELECT broken").and_return("syntax error at or near \"broken\"")
    allow(generator).to receive(:validate_statement).with("SELECT 1").and_return(nil)

    result = generator.run!

    expect(result[:name]).to eq("Donation totals fixed")
    expect(result[:statement]).to eq("SELECT 1")
    expect(generator).to have_received(:validate_statement).twice
    expect(request_payloads.second.dig("messages", 1, "content")).to include("syntax error at or near \"broken\"")
  end

  it "raises after 10 failed attempts" do
    generator = described_class.new(prompt: "Show donation totals", conn: double)
    allow(generator).to receive(:generate_candidate).and_return({ name: "Donation totals", statement: "SELECT 1" })
    allow(generator).to receive(:validate_statement).and_return("syntax error")

    expect { generator.run! }.to raise_error(Blazer::AiQueryGenerator::InvalidResponseError, /after 10 attempts/)
    expect(generator).to have_received(:generate_candidate).exactly(10).times
  end
end
