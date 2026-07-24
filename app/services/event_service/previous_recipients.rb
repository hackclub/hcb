# frozen_string_literal: true

module EventService
  class PreviousRecipients
    RESULT_LIMIT = 7
    CANDIDATES_PER_SOURCE = 28 # how many max candidates to load from each source (ach checks etc)

    Recipient = Data.define(:created_at, :name, :email)

    SOURCES = {
      PaymentRecipient => %i[name email],
      AchTransfer      => %i[recipient_name recipient_email],
      IncreaseCheck    => %i[recipient_name recipient_email],
      Wire             => %i[recipient_name recipient_email],
    }.freeze

    def initialize(event, query: nil)
      @event = event
      @query = query.presence
    end

    def exists?
      list.any?
    end

    def list
      candidates
        .sort_by(&:created_at).reverse
        .uniq { |r| r.email.downcase }
        .first(RESULT_LIMIT)
        .map { |r| { name: r.name, email: r.email } }
    end

    private

    def candidates
      @candidates ||= SOURCES.flat_map do |model, (name_col, email_col)|
        rows_for(model, name_col, email_col)
      end
    end

    def rows_for(model, name_col, email_col)
      table  = model.arel_table
      email  = table[email_col]
      name   = table[name_col]

      scope = model.unscoped.where(event: @event)
                   .where.not(name_col => [nil, ""])
                   .where.not(email_col => [nil, ""])
                   .where.not(matching_payee_exists(email))

      if @query
        scope = scope.where(name.matches(like).or(email.matches(like)))
      end

      scope.order(created_at: :desc)
           .limit(CANDIDATES_PER_SOURCE)
           .pluck(:created_at, name_col, email_col)
           .map { |created_at, name, email| Recipient.new(created_at, name, email) }
    end

    def matching_payee_exists(email_column)
      payees = Payee.arel_table
      lower  = ->(col) { Arel::Nodes::NamedFunction.new("LOWER", [col]) }

      subquery = payees.project(1)
                       .where(payees[:event_id].eq(@event.id))
                       .where(lower.call(payees[:email]).eq(lower.call(email_column)))

      Arel::Nodes::Exists.new(subquery)
    end

    def like
      @like ||= "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%" if @query
    end

  end
end
