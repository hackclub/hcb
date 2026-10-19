# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CSV Injection Protection", type: :model do
  describe "Export::Event::Transactions::Csv" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }

    it "protects against CSV formula injection in transaction exports" do
      # Create a transaction with a dangerous formula in custom_memo
      hcb_code = create(:hcb_code)
      ct = create(:canonical_transaction,
                  hcb_code: hcb_code.hcb_code,
                  custom_memo: "=1+1+cmd|'/c calc'!A1")

      # Associate the transaction with the event
      create(:canonical_event_mapping, canonical_transaction: ct, event:)

      export = Export::Event::Transactions::Csv.new(
        requested_by: user,
        event_id: event.id,
        public_only: false
      )
      export.save!

      content = export.content

      # Parse the CSV and look for the dangerous formula
      csv_rows = CSV.parse(content)

      # Find rows containing our formula
      dangerous_rows = csv_rows.select { |row| row[1]&.include?("calc") }

      expect(dangerous_rows).not_to be_empty, "Test formula not found in export"

      dangerous_memo = dangerous_rows.first[1]

      # Verify the formula is escaped with a leading single quote
      expect(dangerous_memo).to start_with("'"),
                                "Formula '#{dangerous_memo}' should be escaped with a leading single quote to prevent execution in Excel"

      # Verify the original formula content is preserved after the quote
      expect(dangerous_memo).to eq("'=1+1+cmd|'/c calc'!A1"),
                                "Expected escaped formula to be \"'=1+1+cmd|'/c calc'!A1\" but got \"#{dangerous_memo}\""
    end

    it "protects against formulas starting with @" do
      hcb_code = create(:hcb_code)
      ct = create(:canonical_transaction,
                  hcb_code: hcb_code.hcb_code,
                  custom_memo: "@SUM(A1:A10)")

      create(:canonical_event_mapping, canonical_transaction: ct, event:)

      export = Export::Event::Transactions::Csv.new(
        requested_by: user,
        event_id: event.id,
        public_only: false
      )
      export.save!

      content = export.content
      csv_rows = CSV.parse(content)
      formula_rows = csv_rows.select { |row| row[1]&.include?("@SUM") }

      expect(formula_rows.first[1]).to eq("'@SUM(A1:A10)")
    end

    it "protects against formulas starting with +" do
      hcb_code = create(:hcb_code)
      ct = create(:canonical_transaction,
                  hcb_code: hcb_code.hcb_code,
                  custom_memo: "+1+1")

      create(:canonical_event_mapping, canonical_transaction: ct, event:)

      export = Export::Event::Transactions::Csv.new(
        requested_by: user,
        event_id: event.id,
        public_only: false
      )
      export.save!

      content = export.content
      csv_rows = CSV.parse(content)
      formula_rows = csv_rows.select { |row| row[1]&.include?("+1+1") }

      expect(formula_rows.first[1]).to eq("'+1+1")
    end

    it "preserves legitimate negative numbers" do
      hcb_code = create(:hcb_code)
      ct = create(:canonical_transaction,
                  hcb_code: hcb_code.hcb_code,
                  custom_memo: "Refund of -50.00")

      create(:canonical_event_mapping, canonical_transaction: ct, event:)

      export = Export::Event::Transactions::Csv.new(
        requested_by: user,
        event_id: event.id,
        public_only: false
      )
      export.save!

      content = export.content
      csv_rows = CSV.parse(content)
      memo_rows = csv_rows.select { |row| row[1]&.include?("Refund") }

      # The memo should NOT be escaped since it's legitimate text
      expect(memo_rows.first[1]).to eq("Refund of -50.00")
    end

    it "preserves safe text content" do
      hcb_code = create(:hcb_code)
      ct = create(:canonical_transaction,
                  hcb_code: hcb_code.hcb_code,
                  custom_memo: "Pizza delivery for meeting")

      create(:canonical_event_mapping, canonical_transaction: ct, event:)

      export = Export::Event::Transactions::Csv.new(
        requested_by: user,
        event_id: event.id,
        public_only: false
      )
      export.save!

      content = export.content
      csv_rows = CSV.parse(content)
      memo_rows = csv_rows.select { |row| row[1]&.include?("Pizza") }

      expect(memo_rows.first[1]).to eq("Pizza delivery for meeting")
    end
  end

end
