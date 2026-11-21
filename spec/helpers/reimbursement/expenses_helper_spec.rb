# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::ExpensesHelper, type: :helper do
  describe "#move_expense_report_options" do
    let(:owner) { create(:user) }
    let(:event) { create(:event) }
    let(:report) { create(:reimbursement_report, user: owner, event:) }
    let!(:same_event_draft) { create(:reimbursement_report, user: owner, event:, name: "Same event") }
    let!(:other_event_draft) { create(:reimbursement_report, user: owner, name: "Other event") }

    before do
      create(:reimbursement_report, user: owner, event:, aasm_state: "submitted") # not a draft
      create(:reimbursement_report, event:) # someone else's draft
      allow(helper).to receive(:admin_signed_in?).and_return(false)
    end

    it "lists the owner's other draft reports for the owner" do
      allow(helper).to receive(:current_user).and_return(owner)

      expect(helper.move_expense_report_options(report)).to contain_exactly(
        ["Same event", same_event_draft.id],
        ["Other event", other_event_draft.id]
      )
    end

    it "limits an organizer to the owner's drafts in the report's event" do
      allow(helper).to receive(:current_user).and_return(create(:user))

      expect(helper.move_expense_report_options(report)).to eq([["Same event", same_event_draft.id]])
    end

    it "queries once per request" do
      allow(helper).to receive(:current_user).and_return(owner)

      first = helper.move_expense_report_options(report)
      create(:reimbursement_report, user: owner, event:, name: "Created later")

      expect(helper.move_expense_report_options(report)).to eq(first)
    end
  end
end
