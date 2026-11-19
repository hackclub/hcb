# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreakdownEngine::Tags do
  let(:event) { create(:event) }
  let(:tag) { Tag.create!(event:, label: "Snacks", emoji: "🍪", color: "red") }

  def tag_transaction(amount_cents, date)
    canonical_transaction = create(:canonical_transaction, amount_cents:, date:).reload
    hcb_code = HcbCode.find_or_create_by!(hcb_code: canonical_transaction.hcb_code)
    HcbCodeTag.insert_all!([{ hcb_code_id: hcb_code.id, tag_id: tag.id }])
  end

  it "includes the first and last day of a calendar year and nothing outside it" do
    tag_transaction(-1_00, Date.new(2024, 12, 31))
    tag_transaction(-10_00, Date.new(2025, 1, 1))
    tag_transaction(-100_00, Date.new(2025, 12, 31))
    tag_transaction(-1_000_00, Date.new(2026, 1, 1))

    start_date, end_date = BreakdownEngine.date_range("2025")

    expect(described_class.new(event, start_date:, end_date:).run.sole[:value]).to eq(110.0)
  end
end
