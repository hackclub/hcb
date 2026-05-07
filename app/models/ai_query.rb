# frozen_string_literal: true

# == Schema Information
#
# Table name: ai_queries
#
#  id                   :bigint           not null, primary key
#  attempts             :jsonb            not null
#  conversation_history :jsonb            not null
#  generated_name       :string
#  prompt               :text             not null
#  status               :string           default("pending"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  blazer_query_id      :bigint
#  creator_id           :bigint
#
# Indexes
#
#  index_ai_queries_on_blazer_query_id  (blazer_query_id)
#  index_ai_queries_on_creator_id       (creator_id)
#  index_ai_queries_on_status           (status)
#
class AiQuery < ApplicationRecord
  belongs_to :creator, class_name: "User", optional: true
  belongs_to :blazer_query, class_name: "Blazer::Query", optional: true

  enum :status, {
    pending: "pending",
    generating: "generating",
    success: "success",
    failed: "failed"
  }

  validates :prompt, presence: true

  AI_PREFIX = "[AI] "
  BLAZER_DATA_SOURCE = "main"
  MAX_GENERATION_ATTEMPTS = 10

  # Append a new attempt entry to the JSONB array and persist.
  def record_attempt!(sql:, error:)
    new_attempt = {
      "attempt"      => (attempts.length + 1),
      "sql"          => sql,
      "error"        => error,
      "generated_at" => Time.current.iso8601
    }
    update!(attempts: attempts + [new_attempt])
  end

  # The most recent SQL that ran without error.
  def successful_sql
    attempts.reverse.find { |a| a["error"].nil? }&.dig("sql")
  end

  # The most recent error message, if any.
  def latest_error
    attempts.last&.dig("error")
  end

  # Create or update the associated Blazer::Query with the latest successful SQL.
  # The prompt lives on the AiQuery model so no comment embedding is needed.
  def sync_to_blazer!
    sql = successful_sql
    raise ArgumentError, "No successful SQL to sync" if sql.blank?

    name = "#{AI_PREFIX}#{display_name}"
    attrs = {
      name:,
      statement: sql,
      description: prompt,
      data_source: BLAZER_DATA_SOURCE,
      creator: creator
    }

    if blazer_query
      blazer_query.update!(attrs)
    else
      bq = Blazer::Query.create!(attrs)
      update!(blazer_query: bq)
    end
  end

  # Human-readable name derived from the AI-generated summary or the prompt.
  def display_name
    generated_name.presence || prompt.truncate(60)
  end

  # Broadcast the current state of this record to the show page.
  def broadcast_generation_update
    broadcast_replace_to(
      [self, :generation],
      target: "ai-query-#{id}-progress",
      partial: "admin/ai_queries/progress",
      locals: { ai_query: self }
    )
  end

end
