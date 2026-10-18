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
      class Base < Export
        store_accessor :parameters, :query, :ledger_ids, :all_ledgers, :event_id, :public_only, :filtered

        # Past this many items we email the export rather than serving it inline.
        ASYNC_THRESHOLD = 300

        def async?
          items.limit(ASYNC_THRESHOLD + 1).count > ASYNC_THRESHOLD
        end

        def label
          "#{format_name} export of #{scope_description} for #{event&.name || "a ledger"}"
        end

        def filename
          [
            event&.slug || "ledger",
            filtered ? "filtered_transactions" : "transactions",
            Time.now.strftime("%Y%m%d%H%M")
          ].join("_") + ".#{extension}"
        end

        private

        # Subclasses name their own format.
        def format_name = raise(NotImplementedError)
        def extension = raise(NotImplementedError)

        # Associations a subclass reads per row, preloaded so a large export
        # doesn't turn into one query per transaction.
        def preloads = []

        def items
          @items ||= begin
            items = ::Ledger::Query.new(query).execute(ledgers: ledger_ids, all_ledgers: all_ledgers == true)
            preloads.any? ? items.preload(*preloads) : items
          end
        end

        def event
          return nil if event_id.blank?

          @event ||= ::Event.find_by(id: event_id)
        end

        def scope_description
          filtered ? "filtered transactions" : "all transactions"
        end

        # Account-verification micro-deposits prove ownership of an external
        # account, so their amounts are redacted from transparency viewers.
        def amount_cents_for(item)
          public_only && item.likely_account_verification_related? ? 0 : item.amount_cents
        end

        # Only the organization's own tags; an item can be mapped into several
        # ledgers and carry another organization's tags alongside these.
        def tags_for(item)
          item.tags.select { |tag| tag.event_id == event_id.to_i }.map(&:label)
        end

        def comments_for(item)
          return [] if public_only

          item.comments.reject(&:admin_only?).map(&:content)
        end

      end
    end
  end

end
