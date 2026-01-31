# frozen_string_literal: true

module EventMappingEngine
  module Map
    module HcbCodes
      class Short
        def self.category_slug_for_hcb_code(hcb_code)
          if hcb_code.bank_fee?
            "fiscal-sponsorship-fees"
          elsif hcb_code.fee_revenue?
            "hcb-revenue"
          elsif hcb_code.stripe_service_fee?
            "stripe-service-fees"
          elsif hcb_code.outgoing_fee_reimbursement?
            "stripe-fee-reimbursements"
          else
            nil
          end
        end

        def run
          unmapped_short_codes.find_each(batch_size: 100) do |ct|
            # 1 locate short code id
            hcb_short_code_str = ct.memo.scan(/HCB-\w{5}/).first
            next unless hcb_short_code_str

            short_code = hcb_short_code_str.gsub("HCB-", "").upcase

            hcb_code = ::HcbCode.find_by(short_code:)
            next unless hcb_code

            next unless guess_event_id(hcb_code, ct)

            ActiveRecord::Base.transaction do
              ct.update_column(:hcb_code, hcb_code.hcb_code)

              assign_transaction_category!(hcb_code:, canonical_transaction: ct)

              attrs = {
                canonical_transaction_id: ct.id,
                event_id: guess_event_id(hcb_code, ct),
                subledger_id: guess_subledger_id(hcb_code, ct)
              }
              ::CanonicalEventMapping.create!(attrs)
            end
          end
        end

        private

        def unmapped_short_codes
          ::CanonicalTransaction.unmapped.with_short_code.order("date asc")
        end

        def guess_event_id(hcb_code, ct)
          return hcb_code.outgoing_disbursement.event.id if hcb_code.outgoing_disbursement?
          return hcb_code.incoming_disbursement.event.id if hcb_code.incoming_disbursement?
          return hcb_code.event.try(:id) if hcb_code.events.length == 1

          raise ArgumentError, "attempted to map a transaction with HCB short codes to a multi-event HCB code"
        end

        def guess_subledger_id(hcb_code, ct)
          return hcb_code.outgoing_disbursement.subledger&.id if hcb_code.outgoing_disbursement?
          return hcb_code.incoming_disbursement.subledger&.id if hcb_code.incoming_disbursement?
          return hcb_code.ct&.canonical_event_mapping&.subledger_id if hcb_code.events.length == 1
        end

        def assign_transaction_category!(hcb_code:, canonical_transaction:)
          category_slug = self.class.category_slug_for_hcb_code(hcb_code)

          return unless category_slug

          TransactionCategoryService
            .new(model: canonical_transaction)
            .set!(slug: category_slug, assignment_strategy: "automatic")
        end

      end
    end
  end
end
