# frozen_string_literal: true

module Admin
  class GenerateAiQuery
    AI_QUERY_PREFIX = "[AI] "
    MAX_ATTEMPTS = 10
    DATA_SOURCE = "main"

    Result = Struct.new(:success, :query, :error, keyword_init: true) do
      def success? = success
    end

    DB_SCHEMA = <<~SCHEMA
      PostgreSQL database schema for HCB (Hack Club Bank), a fiscal sponsorship platform for student-run nonprofits.
      All monetary amounts are stored in cents (integers) unless noted otherwise.

      TABLE: events
        id, name (org name), slug, aasm_state (approved/rejected/demo/etc),
        country (integer enum), created_at, demo_mode (bool), fee_waiver_applied (bool),
        fee_waiver_eligible (bool), financially_frozen (bool), is_public (bool),
        parent_id (self-ref for sub-orgs), risk_level (integer), website, short_name,
        point_of_contact_id (FK users), activated_at

      TABLE: users
        id, full_name, email, access_level (0=user 1=admin 2=superadmin 3=auditor),
        created_at, teenager (bool), verified (bool), locked_at (null if not locked),
        joined_as_teenager (bool), discord_id, slug

      TABLE: organizer_positions
        id, user_id, event_id, role (100=member 200=manager), created_at, deleted_at (soft delete)
        -- links users to events they organize

      TABLE: canonical_transactions
        id, amount_cents, date, memo, hcb_code, transaction_source_type, transaction_source_id, created_at
        -- settled/finalized financial transactions

      TABLE: canonical_event_mappings
        id, canonical_transaction_id, event_id
        -- joins canonical_transactions to events

      TABLE: canonical_pending_transactions
        id, amount_cents, date, memo, hcb_code, created_at
        -- pending (not yet settled) transactions

      TABLE: canonical_pending_event_mappings
        id, canonical_pending_transaction_id, event_id

      TABLE: donations
        id, amount (cents), aasm_state (pending/in_transit/deposited/refunded/etc),
        event_id, created_at, anonymous (bool), in_person (bool), email, name,
        fee_covered (bool), recurring_donation_id, hcb_code

      TABLE: invoices
        id, aasm_state, amount_due (cents), amount_paid (cents), amount_remaining (cents),
        event_id, creator_id (FK users), created_at, finalized_at, due_date, item_description,
        item_amount (cents), hcb_code, livemode (bool)

      TABLE: disbursements
        id, amount (cents), aasm_state (pending/reviewing/in_transit/deposited/rejected/errored),
        event_id, source_event_id (where money came from), name, created_at, requested_by_id (FK users)

      TABLE: ach_transfers
        id, amount (cents), aasm_state (pending/approved/rejected/etc), event_id,
        created_at, recipient_name, same_day (bool), hcb_code

      TABLE: increase_checks
        id, amount_cents, aasm_state, event_id, created_at, memo, recipient_name

      TABLE: card_grants
        id, amount (cents), event_id, user_id, created_at, aasm_state,
        merchant_lock (json), category_lock (json)

      TABLE: stripe_cards
        id, event_id, user_id, created_at, aasm_state (active/frozen/canceled),
        card_type (integer: 0=physical 1=virtual)

      TABLE: bank_fees
        id, amount_cents, event_id, created_at, aasm_state

      TABLE: fee_revenues
        id, amount_cents, created_at, event_id

      TABLE: reimbursements (reports)
        id, aasm_state, user_id, event_id, created_at

      TABLE: paypal_transfers
        id, amount_cents, event_id, aasm_state, created_at

      TABLE: wires
        id, amount_cents, event_id, aasm_state, created_at, recipient_name

      TABLE: recurring_donations
        id, amount (cents), event_id, created_at, email, active (bool)

      TABLE: g_suites (Google Workspaces)
        id, event_id, aasm_state, created_at, domain

      NOTES:
      - "organizations" and "events" are the same thing (historical naming)
      - amount_cents and amount are both used; always integer cents
      - Use canonical_event_mappings to join canonical_transactions to events
      - aasm_state values vary per table; common ones: approved, active, pending, rejected, canceled
      - organizer_positions with deleted_at IS NULL = active organizers
      - Use DATE_TRUNC for time-based grouping, e.g. DATE_TRUNC('month', created_at)
      - LIMIT results to reasonable numbers (50-100 rows max) unless aggregating
    SCHEMA

    def initialize(prompt:, user: nil, query_name: nil)
      @prompt = prompt
      @user = user
      @query_name = query_name
    end

    def run
      messages = build_initial_messages
      attempt = 0

      while attempt < MAX_ATTEMPTS
        attempt += 1
        sql = call_openai(messages)

        return Result.new(success: false, error: "AI did not return SQL") if sql.blank?

        error = run_sql_validation(sql)

        if error.nil?
          query = save_query(sql)
          return Result.new(success: true, query:)
        else
          messages << { role: "assistant", content: "```sql\n#{sql}\n```" }
          messages << {
            role: "user",
            content: "That query failed with this error: #{error}\n\nPlease fix it and return only the corrected SQL."
          }
        end
      end

      Result.new(success: false, error: "Failed to generate a valid query after #{MAX_ATTEMPTS} attempts. Last error recorded.")
    end

    private

    def build_initial_messages
      [
        { role: "system", content: system_prompt },
        { role: "user", content: @prompt }
      ]
    end

    def system_prompt
      <<~PROMPT
        You are an expert PostgreSQL analyst for HCB (Hack Club Bank), a fiscal sponsorship platform.
        Generate a single, safe, read-only SELECT SQL query based on the user's request.

        #{DB_SCHEMA}

        RULES:
        - Return ONLY the raw SQL query, no explanation, no markdown code fences
        - Use only SELECT statements; no INSERT, UPDATE, DELETE, DROP, etc.
        - Always include a LIMIT clause (max 500 rows) unless the query is an aggregate
        - Use table aliases for readability
        - When joining transactions to events, use canonical_event_mappings
        - Format monetary output with amount_cents / 100.0 AS amount_dollars when helpful
        - Use meaningful column aliases (e.g. "Total Revenue" not "sum")
        - Ensure the query will actually run without errors
      PROMPT
    end

    def call_openai(messages)
      conn = Faraday.new(url: "https://api.openai.com") do |f|
        f.request :json
        f.request :authorization, "Bearer", -> { Credentials.fetch(:OPENAI, :BI_DASHBOARD) }
        f.response :raise_error
        f.response :json
      end

      payload = { model: "gpt-4o", messages:, temperature: 0.2 }
      response = conn.post("/v1/chat/completions", payload)

      content = response.body.dig("choices", 0, "message", "content").to_s.strip
      extract_sql(content)
    rescue Faraday::Error => e
      Rails.logger.error "[Admin::GenerateAiQuery] OpenAI API error: #{e.message}"
      nil
    end

    def extract_sql(content)
      stripped = content.strip
      return stripped unless stripped.start_with?("```")

      # Remove opening fence line (```sql or ```)
      after_open = stripped.sub(/\A```(?:sql)?\r?\n?/i, "")
      # Remove closing fence
      close_idx = after_open.rindex("\n```")
      after_open = after_open[0...close_idx] if close_idx
      after_open.strip
    end

    def run_sql_validation(sql)
      data_source = Blazer.data_sources[DATA_SOURCE]
      statement = Blazer::Statement.new(sql, data_source)
      result = Blazer::RunStatement.new.perform(statement, {})
      result.error
    rescue StandardError => e
      e.message
    end

    def save_query(sql)
      name = build_query_name
      statement_with_comment = "/* Prompt: #{@prompt.gsub("*/", "* /")} */\n\n#{sql}"

      Blazer::Query.create!(
        name: "#{AI_QUERY_PREFIX}#{name}",
        statement: statement_with_comment,
        description: @prompt,
        data_source: DATA_SOURCE,
        creator: @user
      )
    end

    def build_query_name
      return @query_name if @query_name.present?

      conn = Faraday.new(url: "https://api.openai.com") do |f|
        f.request :json
        f.request :authorization, "Bearer", -> { Credentials.fetch(:OPENAI, :BI_DASHBOARD) }
        f.response :raise_error
        f.response :json
      end

      payload = {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "Generate a short, descriptive title (5-8 words max) for a SQL query based on this description. Return only the title, no punctuation at the end."
          },
          { role: "user", content: @prompt }
        ],
        temperature: 0.3,
        max_tokens: 20
      }
      response = conn.post("/v1/chat/completions", payload)

      response.body.dig("choices", 0, "message", "content").to_s.strip.presence || @prompt.truncate(60)
    rescue StandardError
      @prompt.truncate(60)
    end
  end
end
