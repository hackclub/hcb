# frozen_string_literal: true

require "rails_helper"

RSpec.describe Blazer::AiQuery do
  describe ".relation" do
    it "returns only AI-prefixed queries" do
      ai_query = Blazer::Query.create!(name: "[AI] Donations", statement: "SELECT 1", data_source: "main")
      Blazer::Query.create!(name: "Manual Query", statement: "SELECT 2", data_source: "main")

      expect(described_class.relation).to contain_exactly(ai_query)
    end
  end

  describe ".with_prompt_comment" do
    it "prepends the prompt comment to SQL" do
      statement = described_class.with_prompt_comment(statement: "SELECT 1", prompt: "Show totals")

      expect(statement).to eq("/* AI prompt: Show totals */\nSELECT 1")
    end
  end

  describe ".extract_prompt" do
    it "extracts the prompt from the SQL comment" do
      statement = "/* AI prompt: Show donation totals */\nSELECT 1"

      expect(described_class.extract_prompt(statement)).to eq("Show donation totals")
    end
  end

  describe ".strip_prompt_comment" do
    it "removes the prompt comment from SQL" do
      statement = "/* AI prompt: Show donation totals */\nSELECT 1"

      expect(described_class.strip_prompt_comment(statement)).to eq("SELECT 1")
    end
  end
end
