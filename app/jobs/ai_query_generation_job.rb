# frozen_string_literal: true

class AiQueryGenerationJob < ApplicationJob
  queue_as :default

  def perform(ai_query_id)
    ai_query = AiQuery.find(ai_query_id)

    ai_query.update!(status: :generating)
    ai_query.broadcast_generation_update

    build_initial_conversation!(ai_query) if ai_query.conversation_history.empty?

    AiQuery::MAX_GENERATION_ATTEMPTS.times do
      sql = Admin::GenerateAiQuery.call_openai(ai_query.conversation_history)

      if sql.blank?
        ai_query.record_attempt!(sql: "", error: "AI returned no SQL")
        ai_query.broadcast_generation_update
        history = ai_query.conversation_history + [
          { "role"    => "user",
            "content" => "You returned an empty response. Please return only a valid PostgreSQL SELECT query with no explanation."
          }
        ]
        ai_query.update!(conversation_history: history)
        next
      end

      error = Admin::GenerateAiQuery.validate_sql(sql)
      ai_query.record_attempt!(sql:, error:)
      ai_query.broadcast_generation_update

      if error.nil?
        name = Admin::GenerateAiQuery.generate_name(ai_query.prompt)
        ai_query.update!(generated_name: name)
        ai_query.sync_to_blazer!
        ai_query.update!(status: :success)
        ai_query.broadcast_generation_update
        return
      else
        history = ai_query.conversation_history + [
          { "role" => "assistant", "content" => "```sql\n#{sql}\n```" },
          { "role"    => "user",
            "content" => "That query failed with: #{error}\n\nPlease fix it and return only the corrected SQL."
          }
        ]
        ai_query.update!(conversation_history: history)
      end
    end

    ai_query.update!(status: :failed)
    ai_query.broadcast_generation_update
  end

  private

  def build_initial_conversation!(ai_query)
    history = [
      { "role" => "system", "content" => Admin::GenerateAiQuery::SYSTEM_PROMPT },
      { "role" => "user", "content" => ai_query.prompt }
    ]
    ai_query.update!(conversation_history: history)
  end

end
