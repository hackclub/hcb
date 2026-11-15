# frozen_string_literal: true

class Event
  class StatementOfActivity
    prepend MemoWise

    StatementCategory = Data.define(:slug, :label)

    INTRA_ORG_TRANSFER = StatementCategory.new("intra-organization-transfer", "Intra-organization transfers")
    INTER_ORG_TRANSFER = StatementCategory.new("inter-organization-transfer", "Inter-organization transfers")

    INTERNAL_TRANSFER_SLUG = "internal-transfer"
    DISBURSEMENT_HCB_CODE_REGEX = /\AHCB-(?:500|550)-(\d+)\z/

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
      grouped_transactions.sort_by do |category, _transactions|
        next Float::INFINITY if category.nil? # Put the "Uncategorized" category at the end

        category_totals[category.slug]
      end.to_h
    end

    memo_wise def category_totals
      totals = transactions.includes(:category).group("category.slug").sum(:amount_cents)

      # Move each split's amount from its transaction's category to its own
      categorized_splits.each do |split|
        totals[split.splittable.category&.slug] -= split.amount_cents
        totals[split.category.slug] = totals.fetch(split.category.slug, 0) + split.amount_cents
      end

      # Ideally, we'd use the preprocessed transactions categories provided by `grouped_transactions`. However, in this case, it's more efficient to use the raw `transactions` so that we can compute the majority of these category totals in SQL. Then, we use `grouped_transactions` to correct/replace the category totals for Internal Transfers (which get split into Intra/Inter org transfers)
      if totals.key?(INTERNAL_TRANSFER_SLUG)
        # Internal transfers that aren't a transfer between organizations keep
        # the plain category, so its total is recomputed here too.
        virtual_totals = grouped_transactions
                         .select { |category, _| category&.slug.in?([INTRA_ORG_TRANSFER.slug, INTER_ORG_TRANSFER.slug, INTERNAL_TRANSFER_SLUG]) }
                         .transform_keys(&:slug)
                         .transform_values { |txns| txns.sum(&:amount_cents) }

        totals.except(INTERNAL_TRANSFER_SLUG).merge(virtual_totals)
      else
        totals
      end
    end

    memo_wise def net_asset_change
      transactions.sum(:amount_cents)
    end

    # Repayments pay an expense back, so they lower expenses rather than count
    # as revenue.
    memo_wise def total_revenue
      transactions.where("amount_cents > 0").sum(:amount_cents) - repayments_received
    end

    memo_wise def total_expense
      transactions.where("amount_cents < 0").sum(:amount_cents) + repayments_received
    end

    memo_wise def repayments_received
      repayment_mappings = TransactionCategoryMapping.where(
        categorizable_type: "CanonicalTransaction",
        transaction_category_id: TransactionCategory.where(slug: Repayment::CATEGORY_SLUG).select(:id)
      )

      whole = transactions.where("amount_cents > 0").where(id: repayment_mappings.select(:categorizable_id)).sum(:amount_cents)

      # A split can move part of an incoming transaction into or out of the
      # repayment category.
      whole + categorized_splits.select { |split| split.amount_cents > 0 }.sum do |split|
        [split.category, split.splittable.category].map { |category| category&.slug == Repayment::CATEGORY_SLUG ? split.amount_cents : 0 }.inject(:-)
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

      if @event_group.present?
        write_row.call("Included organizations:", format: bold)
        @event_group.events.each do |event|
          write_row.call(event.name, level: 1)
        end
        write_row.call("Total organization count:", @event_group.events.count)

        current_row += 2 # Give some space before the transaction list
      end

      # Header row for transaction list
      if @event_group.present?
        write_row.call("Transaction Memo", "Amount", "Organization", "URL", format: bold)
      else
        write_row.call("Transaction Memo", "Amount", "URL", format: bold)
      end

      transactions_by_category.to_a.each do |category, transactions|
        category_name = category&.label || "Uncategorized"
        category_total = category_totals[category&.slug] / 100.0

        transactions.each do |transaction|
          memo = transaction.memo
          amount_cents = transaction.amount_cents / 100.0
          url = Rails.application.routes.url_helpers.url_for(transaction.local_hcb_code.hashid)
          if @event_group.present?
            write_row.call(memo, amount_cents, transaction.event.name, url, level: 1)
          else
            write_row.call(memo, amount_cents, url, level: 1)
          end
        end

        write_row.call(category_name, category_total, format: bold)
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

    # Transactions grouped by the category they're reported under. A split with
    # a category of its own is listed as a separate line under that category,
    # and its transaction is listed for only what's left.
    memo_wise def grouped_transactions
      loaded = transactions.includes(:category, :local_hcb_code, :event).to_a
      by_id = loaded.index_by(&:id)

      # These records are only read for the statement and never saved
      categorized_splits.each { |split| by_id[split.splittable_id].amount_cents -= split.amount_cents }

      # A transaction that's split in full has nothing left to list
      split_in_full = categorized_splits.map { |split| by_id[split.splittable_id] }.select { |transaction| transaction.amount_cents.zero? }

      (loaded - split_in_full + categorized_splits).group_by { |line| reporting_category_for(line) }
    end

    # Splits of this statement's transactions that are reported under a
    # category of their own. One without a category stays with its transaction.
    memo_wise def categorized_splits
      TransactionSplit
        .where(splittable_type: "CanonicalTransaction", splittable_id: transactions.select(:id))
        .where.not(transaction_category_id: nil)
        .includes(:category, splittable: [:category, :local_hcb_code, :event])
        .to_a
    end

    def reporting_category_for(transaction)
      category = transaction.category
      return category unless category&.slug == INTERNAL_TRANSFER_SLUG

      disbursement_id = transaction.hcb_code.to_s[DISBURSEMENT_HCB_CODE_REGEX, 1]&.to_i
      return category unless disbursement_id

      intra_organization_disbursement_ids.include?(disbursement_id) ? INTRA_ORG_TRANSFER : INTER_ORG_TRANSFER
    end

    memo_wise def intra_organization_disbursement_ids
      event_ids = events.map(&:id)

      disbursement_ids = transactions
                         .joins(:category_mapping)
                         .where(transaction_category_mappings: { category: TransactionCategory.where(slug: INTERNAL_TRANSFER_SLUG) })
                         .where("canonical_transactions.hcb_code ~ ?", "^HCB-(500|550)-\\d+$")
                         .pluck(Arel.sql("substring(canonical_transactions.hcb_code from 'HCB-(?:500|550)-(\\d+)')::int"))
                         .uniq

      return Set.new if disbursement_ids.empty?

      Disbursement.where(id: disbursement_ids, source_event_id: event_ids, event_id: event_ids)
                  .pluck(:id)
                  .to_set
    end

    def transactions
      CanonicalTransaction
        .joins(:canonical_event_mapping)
        .where(canonical_event_mapping: { event_id: events.map(&:id), subledger_id: nil })
        .where("date between ? AND ?", start_date, end_date)
        .includes(:local_hcb_code)
        .strict_loading
    end

  end

end
