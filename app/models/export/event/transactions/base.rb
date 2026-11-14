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
      # Shared plumbing for the legacy whole-organization exports, which walk
      # the organization's canonical transactions. Each becomes an Export::Row,
      # and an Export::Format turns the rows into the file, so these produce
      # the same columns under the same rules as the ledger exports do.
      class Base < Export
        store_accessor :parameters, :event_id, :start_date, :end_date, :public_only

        delegate :mime_type, to: :formatter

        def async?
          event.canonical_transactions.size > 300
        end

        def label
          "#{format_name} transaction export for #{event.name}"
        end

        def filename
          "#{event.slug}_transactions_#{Time.now.strftime("%Y%m%d%H%M")}.#{formatter.extension}"
        end

        def content
          formatter.content(transactions.map { |ct| row(ct) })
        end

        private

        # Subclasses name their own formatter.
        def formatter = raise(NotImplementedError)
        def format_name = raise(NotImplementedError)

        def transactions
          tx = event.canonical_transactions.includes(local_hcb_code: [:tags, :comments])
          tx = tx.where("date >= ?", start_date) if start_date
          tx = tx.where("date <= ?", end_date) if end_date
          tx.order("date desc")
        end

        def event
          @event ||= ::Event.find(event_id)
        end

        def row(ct)
          hcb_code = ct.local_hcb_code

          ::Export::Row.new(
            date: ct.date,
            memo: hcb_code.memo,
            amount_cents: ct.amount_cents,
            account_verification: ct.likely_account_verification_related?,
            tags: hcb_code.tags.select { |tag| tag.event_id == event_id }.map(&:label),
            comments: hcb_code.comments.reject(&:admin_only?).map(&:content),
            author: hcb_code.author,
            category: ct.category,
            merchant: ct.raw_stripe_transaction&.stripe_transaction&.dig("merchant_data"),
            income_type: income_type_for(hcb_code)
          )
        end

        def income_type_for(hcb_code)
          if hcb_code.donation?
            "Donation"
          elsif hcb_code.invoice?
            "Invoice"
          else
            "Transfer"
          end
        end

      end
    end
  end

end
