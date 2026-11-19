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
    context "with a mileage expense on a non-USD report" do
      let(:user) { create(:user) }
      let(:event) { create(:event) }
      let(:report) { create(:reimbursement_report, user:, event:, currency: "RON") }
      let(:expense) { Reimbursement::Expense::Mileage.create!(report:, value: 33) }

      def stub_rate(rate)
        stub_request(:post, "https://api.wise.com/v3/quotes")
          .to_return(status: 200, body: { rate: }.to_json, headers: { "Content-Type" => "application/json" })
      end

      before do
        stub_rate(4.5)
        expense
        create_session(user, verified: true)
      end

      it "requotes in the destination report's currency when the expense is moved" do
        destination = create(:reimbursement_report, user:, event:, currency: "PLN")
        stub_rate(4)

        patch(:update, params: { id: expense.id, reimbursement_expense: { value: "33.0", reimbursement_report_id: destination.id } })

        expect(flash[:error]).to be_blank
        expect(expense.reload).to have_attributes(report: destination, value: 33, amount_cents: 33 * 70 * 4)
      end

      it "shows an error instead of saving when the exchange rate can't be fetched" do
        stub_request(:post, "https://api.wise.com/v3/quotes").to_return(status: 500)

        patch(:update, params: { id: expense.id, reimbursement_expense: { value: "10" } })

        expect(response).to redirect_to(report)
        expect(flash[:error]).to match(/exchange rate/i)
        expect(expense.reload).to have_attributes(value: 33, amount_cents: (33 * 70 * 4.5).round)
      end

      it "converts the miles when a standard expense is switched to mileage" do
        standard = create(:reimbursement_expense, report:, value: 1000)

        patch(:update, params: { id: standard.id, reimbursement_expense: { type: "Reimbursement::Expense::Mileage" } })

        expect(standard.reload).to have_attributes(type: "Reimbursement::Expense::Mileage", amount_cents: 1000 * 70 * 4.5)
      end

      it "uses the entered amount when a mileage expense is switched to standard" do
        patch(:update, params: { id: expense.id, reimbursement_expense: { type: "Reimbursement::Expense", value: "500" } })

        expect(Reimbursement::Expense.find(expense.id)).to have_attributes(type: "Reimbursement::Expense", amount_cents: 500_00)
      end

      it "shows an error instead of crashing when a move to another organization can't be saved" do
        create(:organizer_position, user:, event:)
        destination_event = create(:event)
        create(:organizer_position, user:, event: destination_event)

        patch(:update, params: { id: expense.id, reimbursement_expense: { type: "Bogus", event_id: destination_event.id } })

        expect(response).to redirect_to(report)
        expect(flash[:error]).to match(/valid expense type/i)
        expect(expense.reload).to have_attributes(report:, type: "Reimbursement::Expense::Mileage")
      end

      it "keeps the expense on its report when the move can't be requoted" do
        destination = create(:reimbursement_report, user:, event:, currency: "PLN")
        stub_request(:post, "https://api.wise.com/v3/quotes").to_return(status: 500)

        patch(:update, params: { id: expense.id, reimbursement_expense: { reimbursement_report_id: destination.id } })

        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to match(/exchange rate/i)
        expect(expense.reload).to have_attributes(report:, amount_cents: (33 * 70 * 4.5).round)
      end
    end

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
