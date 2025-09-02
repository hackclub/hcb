# frozen_string_literal: true

class Event
  class StatementOfActivity
    prepend MemoWise

    attr_reader(:event, :event_group)

    def initialize(event_or_event_group, start_date_param: nil, end_date_param: nil)
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

    memo_wise def category_totals
      transactions.includes(:category).group("category.slug").sum(:amount_cents)
    end

    memo_wise def net_asset_change
      transactions.sum(:amount_cents)
    end

    memo_wise def total_revenue
      transactions.where("amount_cents > 0").sum(:amount_cents)
    end

    memo_wise def total_expense
      transactions.where("amount_cents < 0").sum(:amount_cents)
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

    memo_wise def events
      if event_group
        event_group.events.to_a
      else
        [event]
      end
    end

  end

end
