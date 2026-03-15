# frozen_string_literal: true

require "rails_helper"

RSpec.describe SafeCsv do
  describe ".sanitize" do
    context "with dangerous formulas" do
      it "sanitizes values starting with =" do
        expect(SafeCsv.sanitize("=1+1")).to eq("'=1+1")
        expect(SafeCsv.sanitize("=SUM(A1:A10)")).to eq("'=SUM(A1:A10)")
        expect(SafeCsv.sanitize("=cmd|'/c calc'!A1")).to eq("'=cmd|'/c calc'!A1")
      end

      it "sanitizes values starting with @" do
        expect(SafeCsv.sanitize("@SUM(A1:A10)")).to eq("'@SUM(A1:A10)")
      end

      it "sanitizes values starting with |" do
        expect(SafeCsv.sanitize("|calc")).to eq("'|calc")
      end

      it "sanitizes values starting with tab" do
        expect(SafeCsv.sanitize("\t1+1")).to eq("'\t1+1")
      end

      it "sanitizes formulas with + that aren't valid numbers" do
        expect(SafeCsv.sanitize("+1+1")).to eq("'+1+1")
        expect(SafeCsv.sanitize("+SUM(A1)")).to eq("'+SUM(A1)")
      end

      it "sanitizes formulas with - that aren't valid numbers" do
        expect(SafeCsv.sanitize("-1+1")).to eq("'-1+1")
        expect(SafeCsv.sanitize("-SUM(A1)")).to eq("'-SUM(A1)")
      end
    end

    context "with valid negative numbers" do
      it "does not sanitize negative integers as strings" do
        expect(SafeCsv.sanitize("-8")).to eq("-8")
        expect(SafeCsv.sanitize("-100")).to eq("-100")
        expect(SafeCsv.sanitize("-1")).to eq("-1")
      end

      it "does not sanitize negative decimals as strings" do
        expect(SafeCsv.sanitize("-8.50")).to eq("-8.50")
        expect(SafeCsv.sanitize("-0.5")).to eq("-0.5")
        expect(SafeCsv.sanitize("-100.99")).to eq("-100.99")
      end

      it "does not sanitize negative numeric types" do
        expect(SafeCsv.sanitize(-8)).to eq(-8)
        expect(SafeCsv.sanitize(-8.5)).to eq(-8.5)
      end
    end

    context "with valid positive numbers with explicit +" do
      it "does not sanitize positive integers with + sign" do
        expect(SafeCsv.sanitize("+8")).to eq("+8")
        expect(SafeCsv.sanitize("+100")).to eq("+100")
      end

      it "does not sanitize positive decimals with + sign" do
        expect(SafeCsv.sanitize("+8.50")).to eq("+8.50")
        expect(SafeCsv.sanitize("+0.5")).to eq("+0.5")
      end
    end

    context "with valid regular numbers" do
      it "does not sanitize regular integers as strings" do
        expect(SafeCsv.sanitize("8")).to eq("8")
        expect(SafeCsv.sanitize("100")).to eq("100")
      end

      it "does not sanitize regular decimals as strings" do
        expect(SafeCsv.sanitize("8.50")).to eq("8.50")
        expect(SafeCsv.sanitize("0.5")).to eq("0.5")
      end

      it "does not sanitize numeric types" do
        expect(SafeCsv.sanitize(8)).to eq(8)
        expect(SafeCsv.sanitize(8.5)).to eq(8.5)
      end
    end

    context "with safe text values" do
      it "does not sanitize normal text" do
        expect(SafeCsv.sanitize("Normal text")).to eq("Normal text")
        expect(SafeCsv.sanitize("Pizza order")).to eq("Pizza order")
      end
    end

    context "with nil and empty values" do
      it "returns nil unchanged" do
        expect(SafeCsv.sanitize(nil)).to be_nil
      end

      it "returns empty string unchanged" do
        expect(SafeCsv.sanitize("")).to eq("")
      end
    end

    context "with symbols" do
      it "sanitizes dangerous symbols" do
        expect(SafeCsv.sanitize(:"=SUM(A1)")).to eq("'=SUM(A1)")
      end

      it "does not sanitize safe symbols" do
        expect(SafeCsv.sanitize(:normal)).to eq(:normal)
      end
    end

    context "with other types" do
      it "returns dates unchanged" do
        date = Date.today
        expect(SafeCsv.sanitize(date)).to eq(date)
      end

      it "returns booleans unchanged" do
        expect(SafeCsv.sanitize(true)).to eq(true)
        expect(SafeCsv.sanitize(false)).to eq(false)
      end
    end
  end

  describe SafeCsv::Row do
    it "sanitizes fields by default" do
      row = SafeCsv::Row.new([:memo], ["=SUM(A1:A10)"])
      expect(row[:memo]).to eq("'=SUM(A1:A10)")
    end

    it "preserves negative numbers" do
      row = SafeCsv::Row.new([:amount], ["-100"])
      expect(row[:amount]).to eq("-100")
    end

    it "allows opting out of sanitization" do
      row = SafeCsv::Row.new([:memo], ["=SUM(A1:A10)"], false, sanitize: false)
      expect(row[:memo]).to eq("=SUM(A1:A10)")
    end
  end
end
