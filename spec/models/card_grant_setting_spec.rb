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

    it "mirrors reimbursement conversions when the acceptance methods are unset" do
      setting = create(:card_grant_setting)

      expect(setting.reimbursement_conversions_enabled).to be(true)
      expect(setting.allow_stripe_card).to be(true)
      expect(setting.allow_reimbursement_report).to be(true)
    end

    it "does not allow reimbursement acceptance when conversions are disabled" do
      setting = create(:card_grant_setting, reimbursement_conversions_enabled: false)

      expect(setting.allow_reimbursement_report).to be(false)
    end

    it "keeps an explicitly set acceptance method" do
      setting = create(:card_grant_setting, allow_reimbursement_report: false)

      expect(setting.reimbursement_conversions_enabled).to be(true)
      expect(setting.allow_reimbursement_report).to be(false)
    end
  end

  describe "#slack_support?" do
    it "is true for a Slack URL" do
      expect(described_class.new(support_url: "https://hackclub.slack.com/archives/C123").slack_support?).to be true
    end

    it "is false for a non-Slack URL" do
      expect(described_class.new(support_url: "https://hackclub.com").slack_support?).to be false
    end

    it "is false for an invalid mailto URL instead of raising" do
      expect(described_class.new(support_url: "mailto:tagless.hackclub.com").slack_support?).to be false
    end
  end
end
