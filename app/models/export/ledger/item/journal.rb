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
      class Journal < Base
        FORMAT = ::Export::Format::Journal

        private

        # The journal shows no tags.
        def preloads
          [:comments]
        end

        # A card charge reads its merchant off the raw Stripe transactions behind
        # it, which `preloads` doesn't reach (it stops at the linked object).
        # Load them in one query per association rather than one pair of
        # queries per charge.
        def prepare(items)
          card_charges = items.filter_map { |item| item.linked_object if item.linked_object_type == "CardCharge" }
          return if card_charges.empty?

          ActiveRecord::Associations::Preloader.new(
            records: card_charges,
            associations: [:raw_stripe_transactions, :raw_pending_stripe_transaction]
          ).call
        end

        def merchant_for(item)
          return nil unless item.linked_object_type == "CardCharge"

          item.linked_object&.merchant_data
        end

      end
    end
  end

end
