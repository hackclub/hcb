# frozen_string_literal: true

module Admin
  # Stateless utility for OpenAI-powered SQL generation.
  # Orchestration (retries, state, broadcasting) lives in AiQueryGenerationJob.
  module GenerateAiQuery
    DB_SCHEMA = <<~SCHEMA
      PostgreSQL database schema for HCB (Hack Club Bank), a fiscal sponsorship platform
      for student-run nonprofits. All monetary amounts are stored in cents (integers).

      TABLE: events
        id, name (org name), slug, aasm_state (approved/rejected/demo/etc),
        country (integer enum), created_at, demo_mode (bool), fee_waiver_applied (bool),
        fee_waiver_eligible (bool), financially_frozen (bool), is_public (bool),
        parent_id (self-ref for sub-orgs), risk_level (integer), website, activated_at

      TABLE: users
        id, full_name, email, access_level (0=user 1=admin 2=superadmin 3=auditor),
        created_at, teenager (bool), verified (bool), locked_at (null if not locked),
        joined_as_teenager (bool)

      TABLE: organizer_positions
        id, user_id, event_id, role (100=member 200=manager), created_at,
        deleted_at (soft delete — deleted_at IS NULL means active)

      TABLE: canonical_transactions
        id, amount_cents, date, memo, hcb_code, transaction_source_type,
        transaction_source_id, created_at -- settled/finalized transactions

      TABLE: canonical_event_mappings
        id, canonical_transaction_id, event_id -- joins transactions to events

      TABLE: canonical_pending_transactions
        id, amount_cents, date, memo, hcb_code, created_at -- pending transactions

      TABLE: canonical_pending_event_mappings
        id, canonical_pending_transaction_id, event_id

      TABLE: donations
        id, amount (cents), aasm_state, event_id, created_at, anonymous (bool),
        in_person (bool), email, name, recurring_donation_id, hcb_code

      TABLE: invoices
        id, aasm_state, amount_due (cents), amount_paid (cents), event_id,
        creator_id, created_at, finalized_at, due_date, item_description, hcb_code

      TABLE: disbursements
        id, amount (cents), aasm_state, event_id, source_event_id,
        name, created_at, requested_by_id

      TABLE: ach_transfers
        id, amount (cents), aasm_state, event_id, created_at, recipient_name, hcb_code

      TABLE: increase_checks
        id, amount_cents, aasm_state, event_id, created_at, memo, recipient_name

      TABLE: card_grants
        id, amount (cents), event_id, user_id, created_at, aasm_state

      TABLE: stripe_cards
        id, event_id, user_id, created_at,
        aasm_state (active/frozen/canceled), card_type (0=physical 1=virtual)

      TABLE: bank_fees
        id, amount_cents, event_id, created_at, aasm_state

      TABLE: fee_revenues
        id, amount_cents, created_at, event_id

      TABLE: recurring_donations
        id, amount (cents), event_id, created_at, email, active (bool)

      NOTES:
      - "organizations" and "events" are the same concept (historical naming)
      - Use canonical_event_mappings to join canonical_transactions to events
      - organizer_positions with deleted_at IS NULL = active organizers
      - Use DATE_TRUNC('month', col) for monthly grouping
      - LIMIT results (50-100 rows) unless the query is purely aggregate
    SCHEMA

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are an expert PostgreSQL analyst for HCB (Hack Club Bank).
      Generate a single, safe, read-only SELECT SQL query based on the user's request.

      #{DB_SCHEMA}

      RULES:
      - Return ONLY the raw SQL — no explanation, no markdown fences
      - SELECT only; no INSERT, UPDATE, DELETE, DROP, or DDL
      - Always include LIMIT (max 500) unless the query is a pure aggregate
      - Use table aliases for readability
      - Join canonical_transactions to events via canonical_event_mappings
      - Express cents as amount_cents / 100.0 AS amount_dollars where helpful
      - Use descriptive column aliases ("Total Revenue" not "sum")
    PROMPT

    module_function

    def call_openai(conversation_history)
      conn = Faraday.new(url: "https://api.openai.com") do |f|
        f.request :json
        f.request :authorization, "Bearer", -> { Credentials.fetch(:OPENAI, :BI_DASHBOARD) }
        f.response :raise_error
        f.response :json
      end

      payload = { model: "gpt-4o", messages: conversation_history, temperature: 0.2 }
      response = conn.post("/v1/chat/completions", payload)
      raw = response.body.dig("choices", 0, "message", "content").to_s.strip
      extract_sql(raw)
    rescue Faraday::Error => e
      Rails.logger.error "[Admin::GenerateAiQuery] OpenAI error: #{e.message}"
      nil
    end

    def validate_sql(sql)
      data_source = Blazer.data_sources[AiQuery::BLAZER_DATA_SOURCE]
      statement = Blazer::Statement.new(sql, data_source)
      result = Blazer::RunStatement.new.perform(statement, {})
      result.error
    rescue => e
      e.message
    end

    def generate_name(prompt)
      conn = Faraday.new(url: "https://api.openai.com") do |f|
        f.request :json
        f.request :authorization, "Bearer", -> { Credentials.fetch(:OPENAI, :BI_DASHBOARD) }
        f.response :raise_error
        f.response :json
      end

      payload = {
        model: "gpt-4o-mini",
        messages: [
          { "role" => "system",
            "content" => "Write a short title (5-8 words) for a SQL query described below. " \
                         "Return only the title, no punctuation at the end." },
          { "role" => "user", "content" => prompt }
        ],
        temperature: 0.3,
        max_tokens: 20
      }
      response = conn.post("/v1/chat/completions", payload)
      response.body.dig("choices", 0, "message", "content").to_s.strip.presence ||
        prompt.truncate(60)
    rescue
      prompt.truncate(60)
    end

    def extract_sql(content)
      stripped = content.strip
      return stripped unless stripped.start_with?("```")

      after_open = stripped.sub(/\A```(?:sql)?\r?\n?/i, "")
      close_idx = after_open.rindex("\n```")
      after_open = after_open[0...close_idx] if close_idx
      after_open.strip
    end
  end
end
