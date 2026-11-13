# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::ReportPolicy do
  describe "#retry?" do
    it "permits an admin" do
      report = create(:reimbursement_report)

      expect(described_class.new(create(:user, :make_admin), report).retry?).to eq(true)
    end

    it "refuses the report creator" do
      report = create(:reimbursement_report)

      expect(described_class.new(report.user, report).retry?).to eq(false)
    end
  end
end
