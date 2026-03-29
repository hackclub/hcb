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
        store_accessor :parameters, :event_id, :start_date, :end_date, :public_only, :tag_id, :user_id, :transaction_type, :direction, :minimum_amount, :maximum_amount, :missing_receipts, :category_slug, :merchant_id
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
          # If no filters are applied, use simple query for backward compatibility
          if no_filters_applied?
            tx = event.canonical_transactions.includes(local_hcb_code: [:tags, :comments])
            tx = tx.where("date >= ?", start_date) if start_date.present?
            tx = tx.where("date <= ?", end_date) if end_date.present?
            return tx.order("date desc")
          end

          # Use TransactionGroupingEngine for consistent filtering
          engine = TransactionGroupingEngine::Transaction::All.new(
            event_id: event_id,
            tag_id: tag_id,
            expenses: direction == "expenses",
            revenue: direction == "revenue",
            minimum_amount: minimum_amount ? Money.from_amount(minimum_amount.to_f) : nil,
            maximum_amount: maximum_amount ? Money.from_amount(maximum_amount.to_f) : nil,
            start_date: start_date,
            end_date: end_date,
            user: user_id ? User.find_by(id: user_id) : nil,
            missing_receipts: missing_receipts == true || missing_receipts == "true",
            category: category_slug ? TransactionCategory.find_by(slug: category_slug) : nil,
            merchant: merchant_id,
            order_by: :date
          )

          grouped_transactions = engine.run

          # Get the actual canonical transactions from the grouped results
          ct_ids = grouped_transactions.flat_map(&:canonical_transaction_ids)
          canonical_txs = CanonicalTransaction.includes(local_hcb_code: [:tags, :comments])
                                              .where(id: ct_ids)
                                              .order("date desc, id desc")

          # Filter by transaction type if specified
          if transaction_type.present?
            canonical_txs = filter_by_type(canonical_txs)
          end

          canonical_txs
        end

        def no_filters_applied?
          tag_id.blank? && user_id.blank? && transaction_type.blank? &&
          direction.blank? && minimum_amount.blank? && maximum_amount.blank? &&
          missing_receipts.blank? && category_slug.blank? && merchant_id.blank?
          # Note: start_date and end_date are NOT included here because CSV exports
          # already supported date ranges before this feature was added
        end

        def filter_by_type(transactions)
          case transaction_type
          when "card_charge"
            transactions.card_charge
          when "ach"
            transactions.ach
          when "check"
            transactions.check
          when "other"
            transactions.other
          when "paypal"
            transactions.paypal
          when "wire"
            transactions.wire
          when "transfer"
            transactions.transfer
          when "hcb_transfer"
            transactions.hcb_transfer
          else
            transactions
          end
        end

        def event
          @event ||= ::Event.find(event_id)
        end

        def header
          SafeCsv::Row.new(headers, headers.map(&:to_s), true)
        end

        def row(ct)
          SafeCsv::Row.new(
            headers,
            [
              ct.date,
              ct.local_hcb_code.memo,
              public_only && ct.likely_account_verification_related? ? 0 : ct.amount_cents,
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
          [:date, :memo, :amount_cents, :tags, :comments, :user_id, :user_name, :category_slug, :category_label]
        end

      end
    end
  end

end
