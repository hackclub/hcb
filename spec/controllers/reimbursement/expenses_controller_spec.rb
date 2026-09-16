# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::ExpensesController do
  include SessionSupport

  describe "#fit_fees" do
    def capped_wise_report(user: create(:user), maximum_amount_cents: 10_000)
      payout_method = create(:legal_entity_payout_method_wise)
      create(:reimbursement_report,
             user:,
             currency: "GBP",
             maximum_amount_cents:,
             legal_entity_payout_method: payout_method)
    end

    def fitted_quote(local_cents: 8_000)
      {
        initial_local_amount: Money.from_cents(local_cents, "GBP"),
        without_fees_usd_amount: Money.from_cents(9_500, "USD"),
        with_fees_usd_amount: Money.from_cents(10_000, "USD"),
        fees_usd_amount: Money.from_cents(500, "USD")
      }
    end

    it "returns the selected expense allowance after leaving other expenses unchanged" do
      user = create(:user)
      report = capped_wise_report(user:)
      expense = create(:reimbursement_expense, report:, value: 50)
      create(:reimbursement_expense, report:, value: 20)
      allow(WiseTransfer).to receive(:fit_quote_to_maximum).and_return(fitted_quote)
      create_session(user, verified: true)

      get(:fit_fees, params: { expense_id: expense.id, value: "70.00" }, format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "maximum_value"         => "60.0",
        "estimated_fee_cents"   => 500,
        "estimated_total_cents" => 10_000
      )
      expect(expense.reload.value).to eq(BigDecimal("50"))
    end

    it "rejects fitting when the unchanged expenses consume the allowance" do
      user = create(:user)
      report = capped_wise_report(user:)
      expense = create(:reimbursement_expense, report:, value: 70)
      create(:reimbursement_expense, report:, value: 80)
      allow(WiseTransfer).to receive(:fit_quote_to_maximum).and_return(fitted_quote)
      create_session(user, verified: true)

      get(:fit_fees, params: { expense_id: expense.id, value: "70" }, format: :json)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("other expenses")
    end

    it "does not increase an input for a report that already fits" do
      user = create(:user)
      report = capped_wise_report(user:)
      expense = create(:reimbursement_expense, report:, value: 50)
      create(:reimbursement_expense, report:, value: 20)
      allow(WiseTransfer).to receive(:fit_quote_to_maximum).and_return(fitted_quote)
      create_session(user, verified: true)

      get(:fit_fees, params: { expense_id: expense.id, value: "50" }, format: :json)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("already fits")
    end

    it "is available only to the report creator" do
      report = capped_wise_report
      expense = create(:reimbursement_expense, report:, value: 70)
      other_user = create(:user)
      create_session(other_user, verified: true)

      get(:fit_fees, params: { expense_id: expense.id, value: "70" }, format: :json)

      expect(response).to have_http_status(:redirect)
    end

    it "requires a draft capped Wise report" do
      user = create(:user)
      report = create(:reimbursement_report, user:, maximum_amount_cents: nil)
      expense = create(:reimbursement_expense, report:, value: 70)
      create_session(user, verified: true)

      get(:fit_fees, params: { expense_id: expense.id, value: "70" }, format: :json)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("capped Wise")
    end

    it "returns a clear error when Wise quoting fails" do
      user = create(:user)
      report = capped_wise_report(user:)
      expense = create(:reimbursement_expense, report:, value: 70)
      allow(WiseTransfer).to receive(:fit_quote_to_maximum).and_raise(Faraday::ConnectionFailed, "unavailable")
      create_session(user, verified: true)

      get(:fit_fees, params: { expense_id: expense.id, value: "70" }, format: :json)

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body["error"]).to include("Wise could not provide")
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
