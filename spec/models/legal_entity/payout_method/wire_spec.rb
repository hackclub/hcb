# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalEntity::PayoutMethod::Wire, type: :model do
  describe "bic_code" do
    it "normalizes whitespace and case before encrypting" do
      allow(ColumnService).to receive(:get).and_return("country_code" => "GB")

      details = create(:wire_payout_method_details, bic_code: " nwbkgb2l ")

      expect(details.reload.bic_code).to eq("NWBKGB2L")
    end

    it "rejects a BIC with a prefix and never asks Column about it" do
      expect(ColumnService).not_to receive(:get)

      details = build(:wire_payout_method_details, bic_code: "../../entities/ABCDDE11")

      expect(details).not_to be_valid
      expect(details.errors[:bic_code]).to include("is not a valid SWIFT / BIC code")
    end
  end
end
