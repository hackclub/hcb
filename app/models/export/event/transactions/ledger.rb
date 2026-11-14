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
      class Ledger < Base
        # Kept as it has always read in the email that delivers it.
        def label
          "Ledger export for #{event.name}"
        end

        FORMAT = ::Export::Format::Journal

        private

        def preloads
          super + [:transaction_source]
        end

        def merchant_for(ct)
          ct.raw_stripe_transaction&.stripe_transaction&.dig("merchant_data")
        end

      end
    end
  end

end
