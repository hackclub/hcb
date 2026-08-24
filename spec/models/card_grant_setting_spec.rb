# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantSetting, type: :model do
  describe "acceptance methods" do
    it "is invalid when neither acceptance method is enabled" do
      setting = build(:card_grant_setting, allow_stripe_card: false, allow_reimbursement_report: false)

      expect(setting).to be_invalid
      expect(setting.errors[:base]).to include(
        "At least one acceptance method (virtual card or reimbursement report) must be enabled"
      )
    end

    it "is valid when only reimbursement acceptance is enabled" do
      setting = build(:card_grant_setting, allow_stripe_card: false, allow_reimbursement_report: true)

      expect(setting).to be_valid
    end

    it "defaults to virtual card only" do
      setting = create(:card_grant_setting)

      expect(setting.allow_stripe_card).to be(true)
      expect(setting.allow_reimbursement_report).to be(false)
    end
  end
end
