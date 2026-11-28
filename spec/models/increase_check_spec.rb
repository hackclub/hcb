# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncreaseCheck, type: :model do
  describe "memo length" do
    it "allows updating a legacy check whose memo exceeds the current limit" do
      check = create(:increase_check)
      check.update_column(:memo, "x" * 73)

      expect(check.update(column_status: "issued")).to be(true)
    end

    it "rejects changing the memo to one over 40 characters" do
      check = create(:increase_check)

      expect(check.update(memo: "x" * 41)).to be(false)
    end
  end
end
