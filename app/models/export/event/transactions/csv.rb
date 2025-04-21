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
    module Transactions
      class Csv < Export
        store :parameters, accessors: %w[event_id start_date end_date public_only], coder: JSON
        def async?
          event.canonical_transactions.size > 300
        end

        def label
          "CSV transaction export for #{event.name}"
        end

        def filename
          "#{event.slug}_transactions_#{Time.now.strftime("%Y%m%d%H%M")}.csv"
        end

        def mime_type
          "text/csv"
        end

        def content
          e = Enumerator.new do |y|
            y << header.to_s

            transactions.each do |ct|
              y << row(ct).to_s
            end
          end

          e.reduce(:+)
        end

        private

        def transactions
          tx = event.canonical_transactions.includes(local_hcb_code: [:tags, :comments])
          tx = tx.where("date >= ?", start_date) if start_date
          tx = tx.where("date <= ?", end_date) if end_date
          tx.order("date desc")
        end

        def event
          @event ||= ::Event.find(event_id)
        end

        def header
          ::CSV::Row.new(headers, ["date", "memo", "amount_cents", "tags", "comments", "user_id", "user_name"], true)
        end

        def row(ct)
          ::CSV::Row.new(
            headers,
            [
              ct.date,
              ct.local_hcb_code.memo,
              public_only && ct.likely_account_verification_related? ? 0 : ct.amount_cents,
              ct.local_hcb_code.tags.filter { |tag| tag.event_id == event_id }.pluck(:label).join(", "),
              public_only ? "" : ct.local_hcb_code.comments.not_admin_only.pluck(:content).join("\n\n"),
              ct.local_hcb_code.author&.public_id || "",
              ct.local_hcb_code.author&.name || "",
            ]
          )
        end

        def headers
          [:date, :memo, :amount_cents, :tags, :comments]
        end

      end
    end
  end

end
