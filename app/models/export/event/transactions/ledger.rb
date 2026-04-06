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
      class Ledger < Export
        store_accessor :parameters, :event_id, :public_only, :tag_id, :user_id, :transaction_type, :direction, :minimum_amount, :maximum_amount, :missing_receipts, :category_slug, :merchant_id, :start_date, :end_date
        def async?
          event.canonical_transactions.size > 300
        end

        def label
          "Ledger export for #{event.name}"
        end

        def filename
          "#{event.slug}_transactions_#{Time.now.strftime("%Y%m%d%H%M")}.ledger"
        end

        def mime_type
          "text/ledger"
        end

        def content
          journal = ::LedgerJournal::Journal.new
          transactions.each do |ct|
            clean_amount = public_only && ct.likely_account_verification_related? ? 0 : ct.amount_cents

            if ct.amount_cents <= 0
              hcb_code = ct.local_hcb_code
              merchant = ct.raw_stripe_transaction&.stripe_transaction&.[]("merchant_data")
              category = "Transfer"
              metadata = {}
              if merchant && !public_only
                category = merchant["category"].humanize.titleize.delete(" ")
                metadata[:merchant] = merchant
                metadata[:comments] = ct.local_hcb_code.comments.not_admin_only.pluck(:content) unless public_only && ct.local_hcb_code.comments.count.zero?
              elsif merchant
                category = "CardCharge"
              end
              journal.transactions << ::LedgerJournal::Transaction.new(
                date: ct.date,
                payee: ct.local_hcb_code.memo,
                metadata:,
                postings: [
                  ::LedgerJournal::Posting.new(account: "Expenses:#{category}", currency: "USD", amount: BigDecimal(clean_amount, 2) / 100)
                ]
              )
            else
              income_type = "Transfer"
              hcb_code = ct.local_hcb_code
              if hcb_code.donation?
                income_type = "Donation"
              elsif hcb_code.invoice?
                income_type = "Invoice"
              end
              journal.transactions << ::LedgerJournal::Transaction.new(
                date: ct.date,
                payee: ct.local_hcb_code.memo,
                postings: [
                  ::LedgerJournal::Posting.new(account: "Income:#{income_type}", currency: "USD", amount: BigDecimal(clean_amount, 2) / 100)
                ]
              )
            end
          end
          return journal.to_s
        end

        private

        def transactions
          # If no filters are applied, use simple query for backward compatibility
          if no_filters_applied?
            return event.canonical_transactions.order("date desc")
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
            missing_receipts: [true, "true"].include?(missing_receipts),
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
            missing_receipts.blank? && category_slug.blank? && merchant_id.blank? &&
            start_date.blank? && end_date.blank?
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

      end
    end
  end

end
