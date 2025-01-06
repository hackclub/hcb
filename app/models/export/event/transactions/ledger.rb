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
        store :parameters, accessors: %w[event_id public_only]
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
          journal = ::Ledger::Journal.new
          event.canonical_transactions.order("date desc").each do |ct|
            clean_amount = public_only && ct.likely_account_verification_related? ? 0 : ct.amount_cents

            if ct.amount_cents <= 0
              hcb_code = ct.local_hcb_code
              merchant = ct.raw_stripe_transaction ? ct.raw_stripe_transaction.stripe_transaction["merchant_data"] : nil
              category = "Transfer"
              metadata = {}
              if merchant && !public_only
                category = merchant["category"].humanize.titleize.delete(" ")
                metadata[:merchant] = merchant
                metadata[:comments] = ct.local_hcb_code.comments.not_admin_only.pluck(:content) unless public_only && ct.local_hcb_code.comments.count.zero?
              elsif merchant
                category = "CardCharge"
              end
              journal.transactions << ::Ledger::Transaction.new(
                date: ct.date,
                payee: ct.local_hcb_code.memo,
                metadata:,
                postings: [
                  ::Ledger::Posting.new(account: "Expenses:#{category}", currency: "USD", amount: BigDecimal(clean_amount, 2) / 100)
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
              journal.transactions << ::Ledger::Transaction.new(
                date: ct.date,
                payee: ct.local_hcb_code.memo,
                postings: [
                  ::Ledger::Posting.new(account: "Income:#{income_type}", currency: "USD", amount: BigDecimal(clean_amount, 2) / 100)
                ]
              )
            end
          end
          return journal.to_s
        end

        private

        def event
          @event ||= ::Event.find(event_id)
        end

      end
    end
  end

end
