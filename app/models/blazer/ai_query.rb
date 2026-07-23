# frozen_string_literal: true

module Blazer
  class AiQuery
    PREFIX = "[AI]"
    PROMPT_COMMENT_PREFIX = "/* AI prompt:"

    class << self
      def count
        relation.count
      end

      def relation
        Blazer::Query.where("name LIKE ?", "#{PREFIX} %")
      end

      def recent
        relation.order(created_at: :desc)
      end

      def ai?(query)
        query.name.to_s.start_with?("#{PREFIX} ")
      end

      def prefixed_name(name)
        clean_name = name.to_s.strip
        clean_name = "Generated query" if clean_name.blank?
        "#{PREFIX} #{clean_name}"
      end

      def with_prompt_comment(statement:, prompt:)
        sql = statement.to_s.strip
        clean_prompt = prompt.to_s.strip

        return sql if clean_prompt.blank?

        sanitized_prompt = clean_prompt.gsub("*/", "* /")
        "/* AI prompt: #{sanitized_prompt} */\n#{sql}"
      end

      def extract_prompt(statement)
        first_line = statement.to_s.lines.first.to_s.strip
        return nil unless first_line.start_with?(PROMPT_COMMENT_PREFIX) && first_line.end_with?("*/")

        first_line
          .delete_prefix(PROMPT_COMMENT_PREFIX)
          .delete_suffix("*/")
          .strip
      end

      def strip_prompt_comment(statement)
        lines = statement.to_s.lines
        return statement.to_s unless lines.first.to_s.strip.start_with?(PROMPT_COMMENT_PREFIX)

        lines.drop(1).join.strip
      end
    end
  end
end
