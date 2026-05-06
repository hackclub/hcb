# frozen_string_literal: true

module Api
  module V4
    module Reimbursement
      class ExpensesController < ApplicationController
        before_action :set_expense, only: [:show, :update, :destroy]

        def index
          @report = ::Reimbursement::Report.find_by_public_id!(params[:report_id])
          authorize @report, :show?
          expenses = @report.expenses.order(:expense_number)
          @total_count = expenses.count
          @expenses = paginate_expenses(expenses)
        end

        def show
          authorize @expense
        end

        def create
          @report = ::Reimbursement::Report.find_by_public_id!(params[:report_id])
          @expense = @report.expenses.build(expense_attrs)

          authorize @expense

          @expense.save!

          if params[:receipt].present?
            ::ReceiptService::Create.new(
              uploader: current_user,
              attachments: Array(params[:receipt]),
              upload_method: :api,
              receiptable: @expense
            ).run!
          end

          render :show, status: :created
        end

        def update
          authorize @expense

          @expense.update!(expense_attrs)

          if params[:receipt].present?
            ::ReceiptService::Create.new(
              uploader: current_user,
              attachments: Array(params[:receipt]),
              upload_method: :api,
              receiptable: @expense
            ).run!
          end

          render :show, status: :ok
        end


        def destroy
          authorize @expense
          @expense.destroy!
          render json: { message: "Expense successfully deleted" }, status: :ok
        end

        private

        def set_expense
          @expense = ::Reimbursement::Expense.find_by_public_id!(params[:id])
        end

        def expense_attrs
          params.require(:reimbursement_expense).permit(:memo, :description, :category, :value)
        end

        def paginate_expenses(expenses)
          limit = [params[:limit]&.to_i || 25, 100].min

          if params[:after]
            cursor = ::Reimbursement::Expense.find_by_public_id(params[:after])
            return render json: { error: "bad_request", messages: ["Invalid cursor"] }, status: :bad_request unless cursor

            expenses = expenses.where("expense_number > ?", cursor.expense_number)
          end

          page = expenses.limit(limit + 1).to_a
          @has_more = page.length > limit
          page.first(limit)
        end

      end
    end
  end
end
