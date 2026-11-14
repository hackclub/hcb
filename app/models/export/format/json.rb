# frozen_string_literal: true

class Export
  module Format
    class Json < Base
      def name = "JSON"
      def mime_type = "application/json"
      def extension = "json"

      def content(rows)
        rows.map { |row| object(row) }.to_json
      end

      private

      def object(row)
        {
          date: row.date,
          memo: row.memo,
          amount_cents: visible_amount_cents(row),
          tags: row.tags.join(", "),
          comments: visible_comments(row),
          user: if row.author.present?
                  {
                    id: row.author.public_id,
                    name: row.author.name,
                  }
                else
                  nil
                end
        }
      end

    end
  end

end
