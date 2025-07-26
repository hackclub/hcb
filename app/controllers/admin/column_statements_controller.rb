# frozen_string_literal: true

module Admin
  class ColumnStatementsController < AdminController
    def index
      @page = params[:page] || 1
      @per = params[:per] || 20
      @statements = Column::Statement.includes(:file_attachment).page(@page).per(@per).order(created_at: :desc)
    end

    def bank_account_summary_report
      statement = Column::Statement.find(params[:column_statement_id])
      url = ColumnService.bank_account_summary_report_url(from_date: statement.start_date, to_date: statement.end_date)
      if url
        redirect_to url, allow_other_host: true
        return
      end

      redirect_to admin_column_statements_path, flash: { info: "No bank account summary report available for this statement, yet." }
    end

  end
end
