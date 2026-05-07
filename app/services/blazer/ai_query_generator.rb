# frozen_string_literal: true

module Blazer
  class AiQueryGenerator
    class InvalidResponseError < StandardError; end

    def initialize(prompt:, conn: nil)
      @prompt = prompt.to_s.strip
      @conn = conn || default_connection
    end

    def run!
      response = @conn.post("/v1/chat/completions", payload)
      content = response.body.dig("choices", 0, "message", "content").to_s
      parsed = parse_json(content)

      statement = parsed[:statement].to_s.strip
      raise InvalidResponseError, "The AI did not return SQL." if statement.blank?

      {
        name: parsed[:name].presence || "Generated query",
        statement:
      }
    end

    private

    def payload
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
            content: @prompt
          }
        ]
      }
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
