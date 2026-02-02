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
      store_accessor :parameters, :end_date
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
        SafeCsv::Row.new(headers, ["id", "name", "postal_code", "contact email", "organizers", "revenue fee", "url", "balance", "total raised", "omitted?"], true)
      end

      def row(event)
        SafeCsv::Row.new(
          headers,
          [
            event.id,
            event.name,
            event.postal_code,
            event.config.contact_email,
            event.users.pluck(:email).join(", "),
            event.plan.revenue_fee_label,
            Rails.application.routes.url_helpers.url_for(event),
            event.balance(end_date: end_date.presence),
            event.total_raised,
            event.omit_stats?
          ]
        )
      end

      def headers
        [:id, :name, :postal_code, :contact_email, :organizers, :url, :balance]
      end

    end
  end

end
