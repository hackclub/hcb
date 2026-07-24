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
      scope = model.unscoped.where(event: @event)
                   .where.not(name_col => [nil, ""])
                   .where.not(email_col => [nil, ""])
                   .where(<<~SQL, event_id: @event.id)
                     NOT EXISTS (
                       SELECT 1 FROM payees
                       WHERE payees.event_id = :event_id
                         AND LOWER(payees.email) = LOWER(#{model.table_name}.#{email_col})
                     )
                   SQL
      scope = scope.where("#{name_col} ILIKE :q OR #{email_col} ILIKE :q", q: like) if like

      scope.order(created_at: :desc)
           .limit(CANDIDATES_PER_SOURCE)
           .pluck(:created_at, name_col, email_col)
           .map { |created_at, name, email| Recipient.new(created_at, name, email) }
    end

    def like
      @like ||= "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%" if @query
    end
  end
end
