# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::Report, type: :model do
  def build_ach
    LegalEntity::PayoutMethod::AchTransfer.new(account_number: "12345678", routing_number: "021000021")
  end

  describe "payout method association" do
    let(:user) { create(:user) }

    describe "setting the payout method on create" do
      it "sets the user's default payout method on the report" do
        pm = user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)

        report = create(:reimbursement_report, user:)

        expect(report.legal_entity_payout_method).to eq(pm)
        expect(report.payout_method).to eq(pm)
      end

      it "leaves the column null when the user has no default" do
        report = create(:reimbursement_report, user:)

        expect(report.legal_entity_payout_method).to be_nil
      end

      it "does not overwrite an explicitly-assigned payout method" do
        default_pm = user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)
        other_pm = user.personal_legal_entity.payout_methods.create!(default: false, details: build_ach)

        report = create(:reimbursement_report, user:, legal_entity_payout_method: other_pm)

        expect(report.legal_entity_payout_method).to eq(other_pm)
        expect(report.legal_entity_payout_method).not_to eq(default_pm)
      end
    end

    describe "#payout_method" do
      it "returns the method set on the report even after the user's default changes" do
        original_pm = user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)
        report = create(:reimbursement_report, user:)

        user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)

        expect(report.reload.payout_method).to eq(original_pm)
      end

      it "falls back to the user's current default for legacy reports with no payout method set" do
        report = create(:reimbursement_report, user:)
        report.update_columns(legal_entity_payout_method_id: nil)

        pm = user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)

        expect(report.reload.payout_method).to eq(pm)
      end
    end
  end
end
