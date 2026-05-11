# frozen_string_literal: true

module Api
  module V4
    module Reimbursement
      class ExpensesController < ApplicationController
        before_action :set_expense, only: [:show, :update, :destroy]

        include ApplicationHelper

        def index
          @report = ::Reimbursement::Report.find_by_public_id!(params[:report_id])
          authorize @report, :show?
          expenses = @report.expenses.order(:expense_number)
          @expenses = paginate_cursor(expenses.to_a, &:public_id)
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

      end
    end
  end
end
