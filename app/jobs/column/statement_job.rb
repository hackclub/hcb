# frozen_string_literal: true

module Column
  class StatementJob < ApplicationJob
    queue_as :low
    def perform(date = DateTime.current.prev_month)
      start_date = date.beginning_of_month
      end_date = date.end_of_month

      transactions_by_report = ::ColumnService.transactions(
        from_date: start_date,
        to_date: end_date
      )

      template = [
        # Must be wrapped in lambdas
        [:date_posted, ->(t) { t["effective_at"] }],
        [:description, ->(t) {
                         transaction_id = t["transaction_id"]
                         if transaction_id.start_with? "acht" # TODO: use `transaction_type` instead
                           ach_transfer = ColumnService.ach_transfer(transaction_id)
                           return "#{ach_transfer["company_name"]} #{ach_transfer["company_entry_description"]}"
                         elsif transaction_id.start_with? "chkt"
                           check_transfer = ColumnService.get "/transfers/checks/#{transaction_id}"
                           return check_transfer["description"]
                         elsif transaction_id.start_with? "book"
                           book_transfer = ColumnService.get "/transfers/book/#{transaction_id}"
                           return book_transfer["description"]
                         end
                         "TRANSACTION"
                       }],
        [:amount_cents, ->(t) { t["available_amount"] }],
        [:bank_account_id, ->(t) { t["bank_account_id"] }],
        [:available_balance, ->(t) { t["available_balance"] }],
        [:check_number, ->(t) {
          transaction_id = t["transaction_id"]
          if transaction_id.start_with? "chkt"
            check_transfer = ColumnService.get "/transfers/checks/#{transaction_id}"
            return check_transfer["check_number"]
          end
        }]
      ]

      serializer = ->(event) do
        template.to_h.transform_values do |field|
          field.call(event)
        end
      end

      header_syms = template.transpose.first
      @headers = header_syms.map { |h| h.to_s.titleize(keep_id_suffix: true) }

      rows = []

      transactions_by_report.each_value do |transactions|
        transactions.reverse.each_with_index do |transaction, transaction_index|
          rows << serializer.call(transaction).values
        end
      end

      Tempfile.create("column_statement_csv") do |file|
        CSV.open(file, "w", headers: @headers, write_headers: true) do |csv|
          rows.each { |row| csv << row }
        end

        column_statement = Column::Statement.new
        column_statement.file.attach(io: File.open(file), filename: "column_statement_report_#{end_date.iso8601}.csv")
        column_statement.start_date = start_date
        column_statement.end_date = end_date
        first_txn = transactions_by_report[transactions_by_report.keys.last].first
        last_txn = transactions_by_report[transactions_by_report.keys.first].last
        column_statement.starting_balance = ::ColumnService.balance_over_time(from_date: start_date, to_date: end_date)[:starting]
        column_statement.closing_balance = ::ColumnService.balance_over_time(from_date: start_date, to_date: end_date)[:closing]
        column_statement.save!
      end

    end


  end
end
