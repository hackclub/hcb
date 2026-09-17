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
      # A plain-text journal in the format read by ledger-cli, hledger and friends.
      class Journal < Base
        def mime_type
          "text/ledger"
        end

        def content
          journal = ::LedgerJournal::Journal.new

          items.each do |item|
            journal.transactions << (item.amount_cents <= 0 ? expense(item) : income(item))
          end

          journal.to_s
        end

        private

        def format_name = "Ledger"
        def extension = "ledger"

        def preloads
          [:comments]
        end

        def expense(item)
          merchant = merchant_data(item)
          metadata = {}

          category = if merchant.nil?
                       "Transfer"
                     elsif public_only || merchant["category"].blank?
                       # Transparency viewers get the shape of the charge without
                       # naming the merchant it was made at.
                       "CardCharge"
                     else
                       metadata[:merchant] = merchant
                       metadata[:comments] = comments_for(item)
                       merchant["category"].humanize.titleize.delete(" ")
                     end

          ::LedgerJournal::Transaction.new(
            date: item.datetime.to_date,
            payee: item.memo,
            metadata:,
            postings: [posting(account: "Expenses:#{category}", item:)]
          )
        end

        def income(item)
          income_type = case item.linked_object_type
                        when "Donation" then "Donation"
                        when "Invoice" then "Invoice"
                        else "Transfer"
                        end

          ::LedgerJournal::Transaction.new(
            date: item.datetime.to_date,
            payee: item.memo,
            postings: [posting(account: "Income:#{income_type}", item:)]
          )
        end

        def posting(account:, item:)
          ::LedgerJournal::Posting.new(
            account:,
            currency: "USD",
            amount: BigDecimal(amount_cents_for(item), 2) / 100
          )
        end

        def merchant_data(item)
          return nil unless item.linked_object_type == "CardCharge"

          item.linked_object&.merchant_data
        end

      end
    end
  end

end
