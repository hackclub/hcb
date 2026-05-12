# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantSetting, type: :model do
  describe "acceptance method validation" do
    it "is valid with only stripe card allowed" do
      setting = build(:card_grant_setting, allow_stripe_card: true, allow_reimbursement_report: false)
      expect(setting).to be_valid
    end

    it "is valid with only reimbursement report allowed" do
      setting = build(:card_grant_setting, allow_stripe_card: false, allow_reimbursement_report: true)
      expect(setting).to be_valid
    end

    it "is valid with both methods allowed" do
      setting = build(:card_grant_setting, allow_stripe_card: true, allow_reimbursement_report: true)
      expect(setting).to be_valid
    end

    it "is invalid with neither method allowed" do
      setting = build(:card_grant_setting, allow_stripe_card: false, allow_reimbursement_report: false)
      expect(setting).not_to be_valid
      expect(setting.errors[:base]).to include("At least one acceptance method (virtual card or reimbursement report) must be enabled")
    end
  end
end
