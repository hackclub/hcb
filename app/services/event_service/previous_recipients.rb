# frozen_string_literal: true

module EventService
  class PreviousRecipients
    RESULT_LIMIT = 7
    CANDIDATES_PER_SOURCE = 28 # how many max candidates to load from each source (ach checks etc)

    Recipient = Data.define(:created_at, :name, :email)
    Source    = Data.define(:model, :name_column, :email_column)

    SOURCES = [
      Source.new(PaymentRecipient, :name,           :email),
      Source.new(AchTransfer,      :recipient_name, :recipient_email),
      Source.new(IncreaseCheck,    :recipient_name, :recipient_email),
      Source.new(Wire,             :recipient_name, :recipient_email),
    ].freeze

    def initialize(event, query: nil)
      @event = event
      @query = query.presence
    end

    def exists?
      candidates.any?
    end

    def list
      @list ||= candidates
                .sort_by(&:created_at).reverse
                .uniq { |recipient| recipient.email.downcase }
                .first(RESULT_LIMIT)
                .map { |recipient| { name: recipient.name, email: recipient.email } }
    end

    private

    def candidates
      @candidates ||= SOURCES.flat_map { |source| rows_for(source) }
    end

    def rows_for(source)
      table = source.model.arel_table
      name  = table[source.name_column]
      email = table[source.email_column]

      scope = source.model.unscoped
                    .where(event: @event)
                    .where.not(source.name_column => [nil, ""])
                    .where.not(source.email_column => [nil, ""])
                    .where.not(matching_payee_exists(email))

      scope = scope.where(name.matches(like).or(email.matches(like))) if @query

      scope.order(created_at: :desc)
           .limit(CANDIDATES_PER_SOURCE)
           .pluck(:created_at, source.name_column, source.email_column)
           .map { |created_at, recipient_name, recipient_email| Recipient.new(created_at, recipient_name, recipient_email) }
    end

    def matching_payee_exists(email_column)
      payees = Payee.arel_table

      subquery = payees.project(1)
                       .where(payees[:event_id].eq(@event.id))
                       .where(lower(payees[:email]).eq(lower(email_column)))

      Arel::Nodes::Exists.new(subquery)
    end

    def lower(column)
      Arel::Nodes::NamedFunction.new("LOWER", [column])
    end

    def like
      @like ||= "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
    end

  end
end
