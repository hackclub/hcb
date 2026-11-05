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
      class Json < Base
        def mime_type
          "application/json"
        end

        def content
          items.map { |item| row(item) }.to_json
        end

        private

        def format_name = "JSON"
        def extension = "json"

        def preloads
          [:tags, :comments]
        end

        def row(item)
          {
            date: item.datetime.to_date,
            memo: item.memo,
            amount_cents: amount_cents_for(item),
            tags: tags_for(item).join(", "),
            comments: comments_for(item),
            user: if item.author.present?
                    {
                      id: item.author.public_id,
                      name: item.author.name,
                    }
                  else
                    nil
                  end
          }
        end

      end
    end
  end

end
