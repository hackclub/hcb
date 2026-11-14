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
    # Exports of ledger items, mirroring ::Ledger::Item.
    module Item
      # Shared plumbing for the exports produced by `Ledger::Query#export`.
      #
      # What's stored is the query, not the rows it matched, so the export re-runs
      # the very query the ledger page ran. That's what lets a filtered export
      # survive the trip through the job queue: nothing has to be reconstructed
      # from request params on the other side.
      #
      # Each item becomes an Export::Row, and an Export::Format turns the rows
      # into the file. Subclasses only say which format, as FORMAT.
      class Base < Export
        include ::Export::Formatted

        store_accessor :parameters, :query, :ledger_ids, :all_ledgers, :event_id, :public_only, :filtered

        # Past this many items we email the export rather than serving it inline.
        ASYNC_THRESHOLD = 300

        # Everything a row reads off an item, preloaded so a large export
        # doesn't turn into one query per transaction.
        PRELOADS = [:tags, :comments, { canonical_transactions: :category, canonical_pending_transactions: :category }].freeze

        def async?
          return @async if defined?(@async)

          @async = items.limit(ASYNC_THRESHOLD + 1).count > ASYNC_THRESHOLD
        end

        def label
          "#{formatter.name} export of #{scope_description} for #{event&.name || "a ledger"}"
        end

        def filename
          [
            event&.slug || "ledger",
            filtered ? "filtered_transactions" : "transactions",
            Time.now.strftime("%Y%m%d%H%M")
          ].join("_") + ".#{formatter.extension}"
        end

        private

        # A chance to load anything a subclass's rows need beyond PRELOADS.
        def prepare(_items); end

        def items
          @items ||= ::Ledger::Query.new(query).execute(ledgers: ledger_ids, all_ledgers: all_ledgers == true).preload(*PRELOADS)
        end

        def rows
          records = items.to_a
          prepare(records)
          records.map { |item| row(item) }
        end

        def row(item)
          ::Export::Row.new(
            date: item.datetime.to_date,
            memo: item.memo,
            amount_cents: item.amount_cents,
            account_verification: item.likely_account_verification_related?,
            # Only the organization's own tags; an item can be mapped into several
            # ledgers and carry another organization's tags alongside these.
            tags: item.tags.select { |tag| tag.event_id == event_id.to_i }.map(&:label),
            comments: item.comments.reject(&:admin_only?).map(&:content),
            author: item.author,
            category: item.category,
            merchant: merchant_for(item),
            income_type: income_type_for(item)
          )
        end

        def income_type_for(item)
          case item.linked_object_type
          when "Donation" then "Donation"
          when "Invoice" then "Invoice"
          else "Transfer"
          end
        end

        def event
          return nil if event_id.blank?

          @event ||= ::Event.find_by(id: event_id)
        end

        def scope_description
          filtered ? "filtered transactions" : "all transactions"
        end

      end
    end
  end

end
