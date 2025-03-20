# frozen_string_literal: true

module PendingEventMappingEngine
  module Settle
    class Invoice
      def run
        unsettled.find_each(batch_size: 100) do |cpt|
          # 1. identify invoice
          invoice = cpt.invoice
          Airbrake.notify("invoice not found for canonical pending transaction #{cpt.id}") unless invoice
          next unless invoice

          event = invoice.event

          # standard case
          if invoice.payout
            prefix = grab_prefix(invoice:)

            # 2. look up canonical - scoped to event for added accuracy
            cts = event.canonical_transactions.where(
              "memo ilike ? and date >= ?",
              "%PAYOUT% #{ActiveRecord::Base.sanitize_sql_like(prefix)}%",
              cpt.date
            ).order("date asc")

            # 2.b special case if invoice is quite old & now results
            # cts = event.canonical_transactions.where("memo ilike '%DONAT% #{prefix[0]}%'") if cts.count < 1 && invoice.created_at < Time.utc(2020, 1, 1) # shorter prefix. see  id 1 for example.

            next if cts.count < 1 # no match found yet. not processed.

            Airbrake.notify("matched more than 1 canonical transaction for canonical pending transaction #{cpt.id}") if cts.count > 1
            ct = cts.first

            # 3. mark no longer pending
            CanonicalPendingTransactionService::Settle.new(
              canonical_transaction: ct,
              canonical_pending_transaction: cpt
            ).run!
          else
            # invoice.manually_marked_as_paid? as true typically
            # special case for invoices that are marked paid but are missing a payout! these seem to be sent to bill.com
            # these typically can match based on amount cents and nearest date as a result

            cts = event.canonical_transactions.where("memo ilike '%bill.com%' and amount_cents = ? and date > ?", invoice.amount_due, invoice.created_at.strftime("%Y-%m-%d"))
            cts = event.canonical_transactions.where("memo ilike 'DEPOSIT' and amount_cents = ? and date > ?", invoice.amount_due, invoice.created_at.strftime("%Y-%m-%d")) unless cts.present? # see sachacks examples
            unless cts.present?
              prefix = grab_prefix_old(invoice:)
              cts = event.canonical_transactions.where(
                "memo ilike ? and date > ?",
                "HACK CLUB EVENT TRANSFER PAYOUT - #{ActiveRecord::Base.sanitize_sql_like(prefix)}%",
                invoice.created_at.strftime("%Y-%m-%d").to_s
              )
            end

            # this code is dangerous: https://hackclub.slack.com/archives/C047Y01MHJQ/p1724699279740259
            # cts = event.canonical_transactions.missing_pending.where("amount_cents = ? and date > ?", cpt.amount_cents, cpt.date) unless cts.present? # see example canonical transaction 198588

            if cts.empty? # no match found yet. not processed.
              Airbrake.notify("Old manually marked as paid invoice #{invoice.id} still doesn't have a matching CT.") if invoice.manually_marked_as_paid_at&.> 2.weeks.ago
              next
            end

            Airbrake.notify("matched more than 1 canonical transaction for canonical pending transaction #{cpt.id}") if cts.count > 1
            ct = cts.first

            # 3. mark no longer pending
            CanonicalPendingTransactionService::Settle.new(
              canonical_transaction: ct,
              canonical_pending_transaction: cpt
            ).run!
          end
        end
      end

      private

      def unsettled
        CanonicalPendingTransaction.unsettled.invoice
      end

      def grab_prefix(invoice:)
        statement_descriptor = invoice.payout.statement_descriptor

        # tx name can be one of two forms, from observation:
        # 1. HACKC PAYOUT [PREFIX] ST-XXXXXXXXXX The Hack Foundation
        #   -- if it's a complete TX
        # 2. HACKC PAYOUT [PREFIX]
        #   -- if it's a pending TX
        # where PREFIX appears in InvoicePayout.statement_descriptor as
        #   "PAYOUT [PREFIX]"
        #
        # We should parse out the PREFIX from the TX.name, try to find any matching
        # InvoicePayouts, and match it.

        cleanse = statement_descriptor.upcase.gsub("HACK CLUB BANK PAYOUT", "")
        cleanse = cleanse.gsub("HACKC PAYOUT", "")
        cleanse = cleanse.gsub("PAYOUT", "")
        cleanse.split(" ")[0][0..2].upcase
      end

      def grab_prefix_old(invoice:)
        statement_descriptor = invoice.sponsor.name.upcase

        # example: HACK CLUB EVENT TRANSFER PAYOUT - BELVED X

        cleanse = statement_descriptor
        cleanse.split(" ")[0][0..5].upcase
      end

    end
  end
end
