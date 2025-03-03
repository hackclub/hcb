# frozen_string_literal: true

module Reimbursement
  class ExpensesController < ApplicationController
    before_action :set_expense, except: [:create]

    def create
      @report = Reimbursement::Report.find(params[:report_id])
      @expense = @report.expenses.build(amount_cents: 0)

      authorize @expense

      if params[:file]
        receipt = ::ReceiptService::Create.new(
          receiptable: @expense,
          uploader: current_user,
          attachments: params[:file],
          upload_method: :quick_expense
        ).run!
        @expense.update(memo: receipt.first.suggested_memo, amount_cents: receipt.first.extracted_total_amount_cents) if receipt.first.suggested_memo
      end

      if @expense.save
        respond_to do |format|
          format.turbo_stream { render turbo_stream: on_create_streams }
          format.html { redirect_to url_for(@report) }
        end
      else
        redirect_to @report, flash: { error: @expense.errors.full_messages.to_sentence }
      end
    end

    def edit
      authorize @expense
    end

    def update
      authorize @expense

      if expense_params[:reimbursement_report_id] && @expense.reimbursement_report_id != expense_params[:reimbursement_report_id]
        @expense.assign_attributes(expense_number: nil, aasm_state: :pending, approved_by_id: nil)
      end
      @expense.assign_attributes(expense_params.except(:event_id))

      authorize @expense # we authorize twice in case the reimbursement_report_id changes

      if expense_params[:event_id].presence
        event = Event.find(expense_params[:event_id])
        report = event.reimbursement_reports.build({ user: @expense.report.user })
        authorize report
        ActiveRecord::Base.transaction do
          report.save!
          @expense.update!(reimbursement_report_id: report.id, expense_number: nil, aasm_state: :pending, approved_by_id: nil)
        end
      end

      if @expense.save
        respond_to do |format|
          format.turbo_stream { render turbo_stream: on_update_streams }
          format.html { redirect_to @expense.report, flash: { success: "Expense successfully updated." } }
        end
      else
        redirect_to @expense.report, flash: { error: @expense.errors.full_messages.to_sentence }
      end
    end

    def approve
      authorize @expense

      @expense.mark_approved!(current_user) if @expense.may_mark_approved?

      respond_to do |format|
        format.turbo_stream { render turbo_stream: on_update_streams }
        format.html { redirect_to @expense.report }
      end
    end

    def unapprove
      authorize @expense

      @expense.mark_pending!(current_user) if @expense.may_mark_pending?

      respond_to do |format|
        format.turbo_stream { render turbo_stream: on_update_streams }
        format.html { redirect_to @expense.report }
      end
    end

    def destroy
      authorize @expense

      if @expense.delete
        respond_to do |format|
          format.turbo_stream { render turbo_stream: on_delete_streams }
          format.html { redirect_to @expense.report, flash: { success: "Expense successfully deleted." } }
        end
      else
        redirect_to @expense.report, flash: { error: @expense.errors.full_messages.to_sentence }
      end
    end

    private

    def expense_params
      params.require(:reimbursement_expense).permit(:value, :memo, :description, :reimbursement_report_id, :event_id, :type, :category).compact_blank
    end

    def set_expense
      @expense = Reimbursement::Expense.find(params[:expense_id] || params[:id])
    end

    def total_turbo_stream
      turbo_stream.replace(:total, partial: "reimbursement/reports/total", locals: { report: @expense.report })
    end

    def blankslate_turbo_stream
      turbo_stream.replace(:blankslate, partial: "reimbursement/reports/blankslate", locals: { report: Reimbursement::Report.find(@expense.reimbursement_report_id) })
    end

    def actions_turbo_stream
      turbo_stream.replace("action-wrapper", partial: "reimbursement/reports/actions", locals: { report: @expense.report, user: @expense.report.user })
    end

    def replace_expense_turbo_stream
      turbo_stream.replace(@expense, partial: "reimbursement/expenses/expense", locals: {
                             expense: @expense.becomes(@expense.type&.constantize || Reimbursement::Expense)
                           })
    end

    def new_expense_turbo_stream
      turbo_stream.append(:expenses, partial: "reimbursement/expenses/expense", locals: { expense: @expense, new: true })
    end

    def delete_expense_turbo_stream
      turbo_stream.remove(@expense)
    end

    def on_create_streams
      [actions_turbo_stream, new_expense_turbo_stream, blankslate_turbo_stream]
    end

    def on_update_streams
      [total_turbo_stream, actions_turbo_stream, replace_expense_turbo_stream]
    end

    def on_delete_streams
      [total_turbo_stream, actions_turbo_stream, turbo_stream.remove(@expense), blankslate_turbo_stream]
    end

  end
end
