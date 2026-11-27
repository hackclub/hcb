# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::ExpensesController do
  include SessionSupport

  describe "#create" do
    it "categorizes new mileage expenses as Mileage" do
      user = create(:user)
      event = create(:event)
      create(:organizer_position, user:, event:)
      report = create(:reimbursement_report, user:, event:)

      create_session(user, verified: true)

      post(:create, params: { report_id: report.id, type: "mileage" })

      expect(report.expenses.sole).to have_attributes(type: "Reimbursement::Expense::Mileage", category: "Mileage")
    end
  end

  describe "#update" do
    context "when event_id points to an event the user does not belong to" do
      it "blocks the event change and leaves expense state untouched" do
        attacker = create(:user)
        attacker_event = create(:event)
        create(:organizer_position, user: attacker, event: attacker_event)

        victim_event = create(:event)

        report = create(:reimbursement_report, user: attacker, event: attacker_event)
        expense = create(:reimbursement_expense, report:)
        original_state = expense.aasm_state
        original_expense_number = expense.expense_number

        create_session(attacker, verified: true)

        patch(:update, params: {
                id: expense.id,
                reimbursement_expense: { event_id: victim_event.id }
              })

        expect(flash[:error]).to match(/not authorized/i)
        expect(expense.reload.event).to eq(attacker_event)
        expect(expense.aasm_state).to eq(original_state)
        expect(expense.expense_number).to eq(original_expense_number)
        expect(expense.approved_by_id).to be_nil
      end
    end

    context "when event_id points to an event the user manages" do
      it "allows the update" do
        user = create(:user)
        source_event = create(:event)
        create(:organizer_position, user:, event: source_event)
        destination_event = create(:event)
        create(:organizer_position, user:, event: destination_event)

        report = create(:reimbursement_report, user:, event: source_event)
        expense = create(:reimbursement_expense, report:)

        create_session(user, verified: true)

        patch(:update, params: {
                id: expense.id,
                reimbursement_expense: { event_id: destination_event.id }
              })

        expect(expense.reload.event).to eq(destination_event)
      end
    end

    context "when event_id points to an event where the user is only a member (not manager)" do
      it "blocks the event change" do
        user = create(:user)
        source_event = create(:event)
        create(:organizer_position, user:, event: source_event)
        destination_event = create(:event)
        create(:organizer_position, user:, event: destination_event, role: :member)

        report = create(:reimbursement_report, user:, event: source_event)
        expense = create(:reimbursement_expense, report:)

        create_session(user, verified: true)

        patch(:update, params: {
                id: expense.id,
                reimbursement_expense: { event_id: destination_event.id }
              })

        expect(flash[:error]).to match(/not authorized/i)
        expect(expense.reload.event).to eq(source_event)
      end
    end

    context "when the actor is an admin" do
      it "allows changing to any event" do
        admin = create(:user, :make_admin)
        source_event = create(:event)
        destination_event = create(:event)

        report = create(:reimbursement_report, user: admin, event: source_event)
        expense = create(:reimbursement_expense, report:)

        create_session(admin, verified: true)

        patch(:update, params: {
                id: expense.id,
                reimbursement_expense: { event_id: destination_event.id }
              })

        expect(flash[:error]).to be_blank
        expect(expense.reload.event).to eq(destination_event)
      end
    end

    context "when a manager moves an expense to another report" do
      let(:manager) { create(:user) }
      let(:event) { create(:event) }
      let(:owner) { create(:user) }
      let(:expense) { create(:reimbursement_expense, report: create(:reimbursement_report, user: owner, event:)) }

      before do
        create(:organizer_position, user: manager, event:)
        create_session(manager, verified: true)
      end

      it "allows another of the owner's reports" do
        destination = create(:reimbursement_report, user: owner, event:)

        patch(:update, params: { id: expense.id, reimbursement_expense: { reimbursement_report_id: destination.id } })

        expect(flash[:error]).to be_blank
        expect(expense.reload.report).to eq(destination)
      end

      it "refuses someone else's report, even in an event they manage" do
        original_report = expense.report
        destination = create(:reimbursement_report, event:)

        patch(:update, params: { id: expense.id, reimbursement_expense: { reimbursement_report_id: destination.id } })

        expect(flash[:error]).to eq("Expenses can only be moved to another report belonging to the same person.")
        expect(expense.reload.report).to eq(original_report)
      end
    end

    context "when moving an expense by report reference" do
      it "lets an admin move it into a draft report by URL or ID" do
        admin = create(:user, :make_admin)
        expense = create(:reimbursement_expense)
        by_url = create(:reimbursement_report)
        by_id = create(:reimbursement_report)

        create_session(admin, verified: true)

        patch(:update, params: {
                id: expense.id,
                reimbursement_expense: { report_reference: "https://hcb.hackclub.com/reimbursement/reports/#{by_url.hashid}?tab=1" }
              })

        expect(flash[:error]).to be_blank
        expect(expense.reload.report).to eq(by_url)

        patch(:update, params: { id: expense.id, reimbursement_expense: { report_reference: by_id.id.to_s } })

        expect(expense.reload.report).to eq(by_id)
      end

      it "refuses to move it into a report that isn't a draft" do
        admin = create(:user, :make_admin)
        expense = create(:reimbursement_expense)
        submitted = create(:reimbursement_report, aasm_state: "submitted")

        create_session(admin, verified: true)

        patch(:update, params: { id: expense.id, reimbursement_expense: { report_reference: submitted.hashid } })

        expect(flash[:error]).to eq("Expenses can only be moved into draft reports.")
        expect(expense.reload.report).not_to eq(submitted)
      end

      it "is admin-only" do
        user = create(:user)
        event = create(:event)
        create(:organizer_position, user:, event:)
        expense = create(:reimbursement_expense, report: create(:reimbursement_report, user:, event:))
        destination = create(:reimbursement_report, user:, event:)

        create_session(user, verified: true)

        patch(:update, params: { id: expense.id, reimbursement_expense: { report_reference: destination.hashid } })

        expect(flash[:error]).to match(/not authorized/i)
        expect(expense.reload.report).not_to eq(destination)
      end
    end

  end

  describe "#approve" do
    render_views

    def submitted_eur_report(expense_count:)
      report = create(:reimbursement_report, aasm_state: "submitted", currency: "EUR")
      expense_count.times { create(:reimbursement_expense, report:) }
      report
    end

    it "emits an open_modal stream prompting reimbursement when the last pending expense is approved" do
      admin = create(:user, :make_admin)
      report = submitted_eur_report(expense_count: 1)
      expense = report.expenses.first

      allow_any_instance_of(Reimbursement::Report).to receive(:wise_transfer_may_exceed_balance?).and_return(false)
      create_session(admin, verified: true)

      post(:approve, params: { expense_id: expense.id }, format: :turbo_stream)

      expect(expense.reload).to be_approved
      expect(response.body).to include('action="open_modal"')
      expect(response.body).to include("all_expenses_approved_modal")
    end

    it "omits the open_modal stream while other expenses remain pending" do
      admin = create(:user, :make_admin)
      report = submitted_eur_report(expense_count: 2)
      expense = report.expenses.first

      allow_any_instance_of(Reimbursement::Report).to receive(:wise_transfer_may_exceed_balance?).and_return(false)
      create_session(admin, verified: true)

      post(:approve, params: { expense_id: expense.id }, format: :turbo_stream)

      expect(expense.reload).to be_approved
      expect(response.body).not_to include("open_modal")
    end

  end
end
