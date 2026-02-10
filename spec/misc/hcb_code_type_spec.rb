# frozen_string_literal: true

require "rails_helper"

RSpec.describe("HCB_CODE_TYPE") do
  it "returns the corresponding type for an HCB code" do
    # In order to make sure the SQL version doesn't accidentally diverge from
    # the canonical Ruby implementation, we use some metaprogramming to make
    # sure the return values line up with the relevant constants.
    mapping =
      TransactionGroupingEngine::Calculate::HcbCode
      .constants
      .filter { |const| const.end_with?("_CODE") && const != :HCB_CODE }
      .to_h do |const|
        [
          const.downcase.to_s.chomp("_code"),
          TransactionGroupingEngine::Calculate::HcbCode.const_get(const),
        ]
      end

    mapping.each do |return_value, code|
      hcb_code = "HCB-#{code}-12345"
      expect(hcb_code_type(hcb_code)).to(
        eq(return_value),
        "HCB code #{hcb_code.inspect} should have #{return_value.inspect} type"
      )
    end
  end

  it "returns 'unknown_temporary' for 001 codes" do
    expect(hcb_code_type("HCB-001-12345")).to(eq("unknown_temporary"))
  end

  it "returns NULL if the input is NULL" do
    expect(hcb_code_type(nil)).to be_nil
  end

  it "returns NULL if there is no match" do
    expect(hcb_code_type("HCB-9999-123456")).to be_nil
  end

  def hcb_code_type(input)
    ActiveRecord::Base.connection.select_value("select hcb_code_type($1)", nil, [input])
  end
end
