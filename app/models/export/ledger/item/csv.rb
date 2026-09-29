# frozen_string_literal: true

# == Schema Information
#
# Table name: exports
#
#  id              :bigint           not null, primary key
#  parameters      :jsonb
#  type            :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  requested_by_id :bigint
#
# Indexes
#
#  index_exports_on_requested_by_id  (requested_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (requested_by_id => users.id)
#
class Export
  module Ledger
    module Item
      class Csv < Base
        HEADERS = [:date, :memo, :amount_cents, :amount, :tags, :comments, :user_id, :user_name, :category_slug, :category_label].freeze

        def mime_type
          "text/csv"
        end

        def content
          items.each_with_object(+header.to_s) do |item, csv|
            csv << row(item).to_s
          end
        end

        private

        def format_name = "CSV"
        def extension = "csv"

        def preloads
          [:tags, :comments, { canonical_transactions: :category, canonical_pending_transactions: :category }]
        end

        def header
          SafeCsv::Row.new(HEADERS, HEADERS.map(&:to_s), true)
        end

        def row(item)
          amount_cents = amount_cents_for(item)
          category = item.category

          SafeCsv::Row.new(
            HEADERS,
            [
              item.datetime.to_date,
              item.memo,
              amount_cents,
              format("%.2f", amount_cents / 100.0),
              tags_for(item).join(", "),
              comments_for(item).join("\n\n"),
              item.author&.public_id || "",
              item.author&.name || "",
              category&.slug,
              category&.label,
            ]
          )
        end

      end
    end
  end

end
