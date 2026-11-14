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
      # into the file. Subclasses only say which format, as FORMAT; the format
      # says which fields it reads, and only those are built and preloaded.
      class Base < Export
        include ::Export::Formatted

        store_accessor :parameters, :query, :ledger_ids, :all_ledgers, :event_id, :public_only, :filtered

        # What each optional row field reads off an item.
        PRELOADS_FOR = {
          tags: :tags,
          comments: :comments,
          author: :author,
          category: { canonical_transactions: :category, canonical_pending_transactions: :category },
          merchant: :linked_object,
        }.freeze

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

        # What the rows read off an item, preloaded so a large export doesn't
        # turn into one query per transaction. Only what the format will use:
        # a 50,000-item export shouldn't materialize categories it never shows.
        def preloads
          PRELOADS_FOR.filter_map { |field, associations| associations if reads?(field) }
        end

        # The query preloads what the ledger page reads (linked objects,
        # ledgers, events); an export reads only what its format shows, so
        # start from nothing and preload that.
        def items
          @items ||= ::Ledger::Query.new(query)
                                    .execute(ledgers: ledger_ids, all_ledgers: all_ledgers == true)
                                    .unscope(:preload)
                                    .preload(*preloads)
        end

        def rows
          records = items.to_a
          preload_merchant_data(records) if reads?(:merchant)
          records.map { |item| row(item) }
        end

        def row(item)
          ::Export::Row.new(
            date: item.datetime.to_date,
            memo: item.memo,
            amount_cents: item.amount_cents,
            account_verification: item.likely_account_verification_related?,
            income_type: income_type(donation: item.linked_object_type == "Donation", invoice: item.linked_object_type == "Invoice"),
            **fields_for(item)
          )
        end

        def read_tags(item) = own_tag_labels(item.tags)
        def read_comments(item) = non_admin_comments(item.comments)
        def read_author(item) = item.author
        def read_category(item) = item.category

        def read_merchant(item)
          return nil unless item.linked_object_type == "CardCharge"

          item.linked_object&.merchant_data
        end

        # A card charge reads its merchant off the raw Stripe transactions behind
        # it, which the preloads don't reach (they stop at the linked object).
        # Load them in one query per association rather than one pair of
        # queries per charge.
        def preload_merchant_data(items)
          card_charges = items.filter_map { |item| item.linked_object if item.linked_object_type == "CardCharge" }
          return if card_charges.empty?

          ActiveRecord::Associations::Preloader.new(
            records: card_charges,
            associations: [:raw_stripe_transactions, :raw_pending_stripe_transaction]
          ).call
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
