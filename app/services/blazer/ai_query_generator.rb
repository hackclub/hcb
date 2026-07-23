# frozen_string_literal: true

module Blazer
  class AiQueryGenerator
    class InvalidResponseError < StandardError; end
    MAX_ATTEMPTS = 10

    def initialize(prompt:, conn: nil, data_source: "main")
      @prompt = prompt.to_s.strip
      @conn = conn || default_connection
      @data_source = data_source
    end

    def run!
      feedback = nil
      last_statement = nil

      MAX_ATTEMPTS.times do
        parsed = generate_candidate(feedback:, last_statement:)

        statement = parsed[:statement].to_s.strip
        raise InvalidResponseError, "The AI did not return SQL." if statement.blank?

        error = validate_statement(statement)
        return { name: parsed[:name].presence || "Generated query", statement: } if error.blank?

        feedback = error
        last_statement = statement
      end

      raise InvalidResponseError, "Unable to generate a valid query after #{MAX_ATTEMPTS} attempts."
    end

    private

    def payload(feedback:, last_statement:)
      {
        model: "gpt-4o",
        messages: [
          {
            role: "system",
            content: <<~PROMPT
              You generate SQL for Blazer in a Rails app backed by PostgreSQL.
              Return valid JSON with exactly these keys:
              - name: short descriptive title
              - statement: SQL query only
              Do not include markdown fences or extra keys.
            PROMPT
          },
          {
            role: "user",
            content: user_prompt(feedback:, last_statement:)
          }
        ]
      }
    end

    def user_prompt(feedback:, last_statement:)
      return @prompt if feedback.blank?

      <<~PROMPT
        #{@prompt}

        The previous SQL failed when executed in Blazer.
        Error: #{feedback}
        Failed SQL:
        #{last_statement}

        Please return a corrected SQL query.
      PROMPT
    end

    def generate_candidate(feedback:, last_statement:)
      response = @conn.post("/v1/chat/completions", payload(feedback:, last_statement:))
      content = response.body.dig("choices", 0, "message", "content").to_s
      parse_json(content)
    end

    def parse_json(content)
      cleaned = content.strip
      cleaned = cleaned.delete_prefix("```json").delete_suffix("```").strip if cleaned.start_with?("```json")

      parsed = JSON.parse(cleaned)
      parsed = parsed.first if parsed.is_a?(Array)
      parsed.with_indifferent_access
    rescue JSON::ParserError
      raise InvalidResponseError, "The AI returned an invalid response."
    end

    def validate_statement(statement)
      data_source = Blazer.data_sources[@data_source]
      statement_object = Blazer::Statement.new(statement, data_source)
      result = Blazer::RunStatement.new.perform(
        statement_object,
        user: nil,
        query: nil,
        refresh_cache: false,
        run_id: nil,
        async: false
      )

      return "Query execution returned no result object for data source #{@data_source.inspect}. Verify the data source exists and its connection settings are valid." if result.nil?

      result.error
    rescue StandardError => e
      e.message
    end

    def default_connection
      api_key = Credentials.fetch(:OPENAI, :SUGGESTED_TAGS, fallback: Credentials.fetch(:OPENAI_API_KEY))

      Faraday.new(url: "https://api.openai.com") do |f|
        f.request :json
        f.request :authorization, "Bearer", -> { api_key }
        f.response :raise_error
        f.response :json
      end
    end
  end
end
