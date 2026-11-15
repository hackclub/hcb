# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Item::MemoSearch do
  describe ".tokens" do
    delegate :tokens, to: :described_class

    it "keeps a partial word as a token" do
      expect(tokens("amaz")).to eq(["amaz"])
    end

    it "splits on any whitespace, including non-breaking spaces" do
      expect(tokens("Door\u00A0 Dash")).to eq(["Door", "Dash"])
      expect(tokens("  door\tdash \n")).to eq(["door", "dash"])
    end

    it "treats quotes, including smart quotes, as separators rather than phrases" do
      expect(tokens("“door dash”")).to eq(["door", "dash"])
      expect(tokens('"door dash" uber')).to eq(["door", "dash", "uber"])
      expect(tokens('"unbalanced')).to eq(["unbalanced"])
    end

    it "drops zero-width characters" do
      expect(tokens("door\u200Bdash")).to eq(["doordash"])
    end

    it "strips surrounding punctuation but keeps inner apostrophes" do
      expect(tokens("joe’s, uber!")).to eq(["joe’s", "uber"])
      expect(tokens("(stickers)")).to eq(["stickers"])
    end

    it "drops tokens without a letter or digit, and one-character tokens" do
      expect(tokens("... 🙂 a")).to eq([])
      expect(tokens("a pa")).to eq(["pa"])
    end

    it "is empty for a blank query" do
      expect(tokens("   ")).to eq([])
      expect(tokens(nil)).to eq([])
    end

    it "drops case-insensitive duplicates and tokens contained in another token" do
      expect(tokens("Uber uber UBER")).to eq(["Uber"])
      expect(tokens("Uber ub")).to eq(["Uber"])
      expect(tokens("ub Uber")).to eq(["Uber"])
    end

    it "keeps every distinct word" do
      expect(tokens("aa bb cc dd ee ff gg")).to eq(%w[aa bb cc dd ee ff gg])
    end

    it "truncates each word to MAX_TOKEN_LENGTH characters" do
      expect(tokens("x" * 100)).to eq(["x" * described_class::MAX_TOKEN_LENGTH])
      expect(tokens("a'" * 100).first.length).to eq(described_class::MAX_TOKEN_LENGTH)
    end

    it "only reads the first MAX_QUERY_LENGTH characters of the query" do
      words = ("a".."z").to_a.product(("a".."z").to_a).map { |x, y| "#{x}#{y}q" } # "aaq abq …", none inside another

      expect(tokens(words.join(" "))).to eq(words.first(described_class::MAX_QUERY_LENGTH / 4))
    end

    it "treats control characters as separators" do
      expect(tokens("ab\u0000cd")).to eq(["ab", "cd"])
    end

    it "drops invisible formatting characters" do
      expect(tokens("door\u00ADdash")).to eq(["doordash"])
      expect(tokens("uber\u200Eeats")).to eq(["ubereats"])
    end
  end

  describe ".pattern" do
    it "wraps the token for a substring ILIKE" do
      expect(described_class.pattern("amaz")).to eq("%amaz%")
    end

    it "escapes LIKE metacharacters so they match literally" do
      expect(described_class.pattern("100%")).to eq("%100\\%%")
      expect(described_class.pattern("a_b")).to eq("%a\\_b%")
      expect(described_class.pattern("a\\b")).to eq("%a\\\\b%")
    end

    it "lets any apostrophe variant match any other" do
      expect(described_class.pattern("joe’s")).to eq("%joe_s%")
      expect(described_class.pattern("joe's")).to eq("%joe_s%")
    end
  end
end
