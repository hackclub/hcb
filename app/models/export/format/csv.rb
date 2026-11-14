# frozen_string_literal: true

class Export
  module Format
    class Csv < Base
      HEADERS = [:date, :memo, :amount_cents, :amount, :tags, :comments, :user_id, :user_name, :category_slug, :category_label].freeze

      READS = %i[tags comments author category].freeze

      def name = "CSV"
      def mime_type = "text/csv"
      def extension = "csv"

      def content(rows)
        rows.each_with_object(+header.to_s) do |row, csv|
          csv << line(row).to_s
        end
      end

      private

      def header
        SafeCsv::Row.new(HEADERS, HEADERS.map(&:to_s), true)
      end

      def line(row)
        amount_cents = visible_amount_cents(row)

        SafeCsv::Row.new(
          HEADERS,
          [
            row.date,
            row.memo,
            amount_cents,
            format("%.2f", amount_cents / 100.0),
            row.tags.join(", "),
            visible_comments(row).join("\n\n"),
            row.author&.public_id || "",
            row.author&.name || "",
            row.category&.slug,
            row.category&.label,
          ]
        )
      end

    end
  end

end
