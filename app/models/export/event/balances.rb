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
  module Event
    class Balances < Export
      store :parameters, accessors: %w[], coder: JSON
      def async?
        true
      end

      def label
        "Balances for all events"
      end

      def filename
        "hcb_balances_#{Time.now.strftime("%Y%m%d%H%M")}.csv"
      end

      def mime_type
        "text/csv"
      end

      def content
        e = Enumerator.new do |y|
          y << header.to_s

          events.each do |event|
            y << row(event).to_s
          end
        end

        e.reduce(:+)
      end

      private

      def events
        ::Event.all.not_demo_mode
      end

      def header
        ::CSV::Row.new(headers, ["name", "url", "balance"], true)
      end

      def row(event)
        ::CSV::Row.new(
          headers,
          [
            event.name,
            Rails.application.routes.url_helpers.url_for(event),
            event.balance
          ]
        )
      end

      def headers
        [:name, :url, :balance]
      end

    end
  end

end
