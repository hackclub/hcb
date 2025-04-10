# frozen_string_literal: true

module PendingEventMappingEngine
  module Settle
    class Donation
      def run
        unsettled.find_each(batch_size: 100) do |cpt|
          # 1. identify donation
          donation = cpt.raw_pending_donation_transaction.donation
          Airbrake.notify("Donation not found for canonical pending transaction #{cpt.id}") unless donation
          next unless donation

          next unless donation.payout

          event = donation.event

          prefix = grab_prefix(donation:)

          # 2. look up canonical - using HCB short code
          cts ||= event.canonical_transactions.where("memo ilike ?", "HCKCLB HCB-#{ActiveRecord::Base.sanitize_sql_like(cpt.local_hcb_code.short_code)}%")

          # 2b. look up canonical - scoped to event for added accuracy
          cts ||= event.canonical_transactions.where("memo ilike ?", "%DONAT% #{ActiveRecord::Base.sanitize_sql_like(prefix)}%")

          # 2.b special case if donation is quite old & now results
          cts ||= event.canonical_transactions.where("memo ilike ?", "%DONAT% #{ActiveRecord::Base.sanitize_sql_like(prefix[0])}%") if cts.count < 1 && donation.created_at < Time.utc(2020, 1, 1) # shorter prefix. see Donation id 1 for example.

          next if cts.count < 1 # no match found yet. not processed.

          Airbrake.notify("matched more than 1 canonical transaction for canonical pending transaction #{cpt.id}") if cts.count > 1
          ct = cts.first

          # 3. mark no longer pending
          CanonicalPendingTransactionService::Settle.new(
            canonical_transaction: ct,
            canonical_pending_transaction: cpt
          ).run!
        end
      end

      private

      def unsettled
        CanonicalPendingTransaction.unsettled.donation
      end

      def grab_prefix(donation:)
        statement_descriptor = donation.payout.statement_descriptor

        # tx name can be one of two forms, from observation:
        # 1. HACKC DONATE [PREFIX] ST-XXXXXXXXXX The Hack Foundation
        #   -- if it's a complete TX
        # 2. HACKC DONATE [PREFIX]
        #   -- if it's a pending TX
        # 3. HACK CLUB EVENT DONATION 4 ST-H3J2H7R3A6E1 THE HACK FOUNDATION
        # where PREFIX appears in DonationPayout.statement_descriptor as
        #   "DONATE [PREFIX]"
        #
        # We should parse out the PREFIX from the TX.name, try to find any matching
        # example 1: HACK CLUB EVENT DONATION 4 ST-H3J2H7R3A6E1 THE HACK FOUNDATION
        # example 2: DONATE H3J
        # exmplae 3: DONATION 4EBADC9D7338

        cleanse = statement_descriptor.gsub("HACK CLUB EVENT DONATION", "")
        cleanse = cleanse.gsub("HACKC DONATE", "")
        cleanse = cleanse.gsub("DONATE", "")
        cleanse = cleanse.gsub("DONATION", "")
        cleanse.split(" ")[0][0..2].upcase
      end

    end
  end
end
