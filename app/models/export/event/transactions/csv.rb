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
        include Filterable

        store_accessor :parameters, :event_id, :start_date, :end_date, :public_only, :tag_id, :user_id, :transaction_type, :direction, :minimum_amount, :maximum_amount, :missing_receipts, :category_slug, :merchant_id, :search

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

        def fallback_transactions
          tx = event.canonical_transactions.includes(local_hcb_code: [:tags, :comments])
          tx = tx.where("date >= ?", start_date) if start_date.present?
          tx = tx.where("date <= ?", end_date) if end_date.present?
          tx.order("date desc")
        end

        def no_filters_applied?
          # start_date and end_date are excluded because CSV already supported date
          # ranges via the simple query path before filtered exports were added.
          tag_id.blank? && user_id.blank? && transaction_type.blank? &&
            direction.blank? && minimum_amount.blank? && maximum_amount.blank? &&
            missing_receipts.blank? && category_slug.blank? && merchant_id.blank? &&
            search.blank?
        end

        def event
          @event ||= ::Event.find(event_id)
        end

        def header
          SafeCsv::Row.new(headers, headers.map(&:to_s), true)
        end

        def row(ct)
          amount_cents = public_only && ct.likely_account_verification_related? ? 0 : ct.amount_cents
          SafeCsv::Row.new(
            headers,
            [
              ct.date,
              ct.local_hcb_code.memo,
              amount_cents,
              format("%.2f", amount_cents / 100.0),
              ct.local_hcb_code.tags.filter { |tag| tag.event_id == event_id }.pluck(:label).join(", "),
              public_only ? "" : ct.local_hcb_code.comments.not_admin_only.pluck(:content).join("\n\n"),
              ct.local_hcb_code.author&.public_id || "",
              ct.local_hcb_code.author&.name || "",
              ct.category&.slug,
              ct.category&.label,
            ]
          )
        end

        def headers
          [:date, :memo, :amount_cents, :amount, :tags, :comments, :user_id, :user_name, :category_slug, :category_label]
        end

      end
    end
  end

end
