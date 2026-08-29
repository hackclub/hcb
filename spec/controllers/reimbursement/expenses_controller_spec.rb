# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::ExpensesController do
  include SessionSupport

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

  end
end
