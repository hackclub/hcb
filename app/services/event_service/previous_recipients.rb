# frozen_string_literal: true

module EventService
  class PreviousRecipients
    RESULT_LIMIT = 7
    CANDIDATES_PER_SOURCE = 28 # per source before merging and de-duplicating

    SOURCES = {
      PaymentRecipient => [:name, :email],
      AchTransfer      => [:recipient_name, :recipient_email],
      IncreaseCheck    => [:recipient_name, :recipient_email],
      Wire             => [:recipient_name, :recipient_email],
    }.freeze

    def initialize(event, query: nil)
      @event = event
      @query = query.presence
    end

    def exists?
      candidates.any?
    end

    def list
      @list ||= candidates
        .sort_by(&:first).reverse
        .uniq { |_created_at, _name, email| email.downcase }
        .first(RESULT_LIMIT)
        .map { |_created_at, name, email| { name:, email: } }
    end

    private

    def candidates
      @candidates ||= SOURCES.flat_map { |model, columns| rows_for(model, *columns) }
    end

    def rows_for(model, name_column, email_column)
      table = model.arel_table

      scope = model.unscoped
                   .where(event: @event)
                   .where.not(name_column => [nil, ""])
                   .where.not(email_column => [nil, ""])
                   .where.not(existing_payee(table[email_column]))

      if @query
        scope = scope.where(table[name_column].matches(like).or(table[email_column].matches(like)))
      end

      scope.order(created_at: :desc)
           .limit(CANDIDATES_PER_SOURCE)
           .pluck(:created_at, name_column, email_column)
    end

    def existing_payee(email_column)
      payees = Payee.arel_table

      Arel::Nodes::Exists.new(
        payees.project(1) # same as sql "select 1 from payees"
              .where(payees[:event_id].eq(@event.id))
              .where(lower(payees[:email]).eq(lower(email_column)))
      )
    end

    def lower(column)
      Arel::Nodes::NamedFunction.new("LOWER", [column])
    end

    def like
      @like ||= "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
    end
  end
end
