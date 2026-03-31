# frozen_string_literal: true

class Event
  class StatementOfActivity
    prepend MemoWise

    attr_reader(:event, :event_group, :include_descendants)

    def initialize(
      event_or_event_group,
      start_date_param: nil,
      end_date_param: nil,
      include_descendants: false
    )
      @event_group, @event = nil

      case event_or_event_group
      when Event
        @event = event_or_event_group
      when Event::Group
        @event_group = event_or_event_group
      else
        raise(ArgumentError, "unsupported event_or_event_group: #{event_or_event_group.inspect}")
      end

      @start_date_param = start_date_param
      @end_date_param = end_date_param
      @include_descendants = include_descendants
    end

    def supports_descendants?
      event.present?
    end

    memo_wise def start_date
      if start_date_param.respond_to?(:to_date)
        start_date_param.to_date
      elsif events.present?
        events.map { |event| event.activated_at || event.created_at }.min.to_date
      else
        Time.now.to_date
      end
    end

    memo_wise def end_date
      if end_date_param.respond_to?(:to_date)
        end_date_param.to_date
      else
        Time.now.to_date
      end
    end

    memo_wise def transactions_by_category
      transactions.includes(:category, :local_hcb_code, :event).group_by(&:category).sort_by do |category, _transactions|
        next Float::INFINITY if category.nil? # Put the "Uncategorized" category at the end

        category_totals[category.slug] # I'm using SQL calculated totals since it is faster than Array's sum(&:amount_cents)
      end.to_h
    end

    memo_wise def category_totals
      transactions.includes(:category).group("category.slug").sum(:amount_cents)
    end

    memo_wise def net_asset_change
      transaction_sections.sum { |section| section.fetch(:transactions).sum { |transaction| transaction.fetch(:amount_cents) } }
    end

    memo_wise def total_revenue
      transaction_sections.sum do |section|
        section.fetch(:transactions).sum do |transaction|
          amount_cents = transaction.fetch(:amount_cents)
          amount_cents.positive? ? amount_cents : 0
        end
      end
    end

    memo_wise def total_expense
      transaction_sections.sum do |section|
        section.fetch(:transactions).sum do |transaction|
          amount_cents = transaction.fetch(:amount_cents)
          amount_cents.negative? ? amount_cents : 0
        end
      end
    end

    memo_wise def includes_multiple_organizations?
      event_group.present? || include_descendants
    end

    memo_wise def included_organization_names
      events.map(&:name)
    end

    memo_wise def transaction_sections
      totals = category_totals

      transactions_by_category.map do |category, category_transactions|
        {
          category_name: category&.label || "Uncategorized",
          category_total_cents: totals[category&.slug],
          transactions: category_transactions.map do |transaction|
            {
              memo: transaction.memo,
              amount_cents: transaction.amount_cents,
              organization_name: transaction.event.name,
              url: transaction.local_hcb_code.present? ? Rails.application.routes.url_helpers.url_for(transaction.local_hcb_code) : nil,
            }
          end,
        }
      end
    end

    memo_wise def xlsx
      io = StringIO.new
      workbook = WriteXLSX.new(io)

      bold = workbook.add_format(bold: 1)

      worksheet = workbook.add_worksheet("Statement of Activity")
      subject_name = @event_group&.name || @event.name
      worksheet.write("A1", "#{subject_name}'s Statement of Activity", bold)

      worksheet.set_column("A:A", 40) # Set first column width to 40

      current_row = 2
      write_row = ->(*column_values, level: nil, format: nil) do
        worksheet.write_row(current_row, 0, column_values, format)

        if level
          # Syntax: set_row(row, height, format, hidden, level, collapsed)
          worksheet.set_row(current_row, nil, nil, 0, level)
        end

        current_row += 1
      end

      if includes_multiple_organizations?
        write_row.call("Included organizations:", format: bold)
        included_organization_names.each do |organization_name|
          write_row.call(organization_name, level: 1)
        end
        write_row.call("Total organization count:", included_organization_names.count)

        current_row += 2 # Give some space before the transaction list
      end

      # Header row for transaction list
      write_row.call("Transaction Memo", "Amount", "Organization", "URL", format: bold)

      transaction_sections.each do |section|
        section.fetch(:transactions).each do |transaction|
          write_row.call(
            transaction.fetch(:memo),
            transaction.fetch(:amount_cents) / 100.0,
            transaction.fetch(:organization_name),
            transaction.fetch(:url),
            level: 1
          )
        end

        write_row.call(section.fetch(:category_name), section.fetch(:category_total_cents) / 100.0, nil, nil, format: bold)
      end

      workbook.close
      io.string
    end

    memo_wise def events
      if event_group
        event_group.events.to_a
      elsif include_descendants
        [
          event,
          *Event.where(id: event.descendant_ids).to_a
        ]
      else
        [event]
      end
    end

    private

    attr_reader(:start_date_param, :end_date_param)

    def transactions
      CanonicalTransaction
        .joins(:canonical_event_mapping)
        .where(canonical_event_mapping: { event_id: events.map(&:id), subledger_id: nil })
        .where("date between ? AND ?", start_date, end_date)
        .strict_loading
    end

  end

end
