# frozen_string_literal: true

module EventMappingEngine
  module Map
    module HcbCodes
      class Short
        def run
          unmapped_short_codes.find_each(batch_size: 100) do |ct|
            # 1 locate short code id
            hcb_short_code_str = ct.memo.scan(/HCB-\w{5}/).first
            next unless hcb_short_code_str

            short_code = hcb_short_code_str.gsub("HCB-", "").upcase

            hcb_code = ::HcbCode.find_by(short_code:)
            next unless hcb_code

            next unless guess_event_id(hcb_code)

            ActiveRecord::Base.transaction do
              ct.update_column(:hcb_code, hcb_code.hcb_code)

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
          return hcb_code.event.try(:id) if hcb_code.events.length == 1

          if hcb_code.disbursement?
            if ct.amount_cents.positive?
              return hcb_code.disbursement.source_event_id
            else
              return hcb_code.disbursement.event_id
            end
          end

          raise ArgumentError, "attempted to map a transaction with HCB short codes to a multi-event HCB code"
        end

        def guess_subledger_id(hcb_code, ct)
          return hcb_code.ct&.canonical_event_mapping&.subledger_id if hcb_code.events.length == 1

          if hcb_code.disbursement?
            if ct.amount_cents.positive?
              return hcb_code.disbursement.source_subledger_id
            else
              return hcb_code.disbursement.destination_subledger_id
            end
          end
        end

      end
    end
  end
end
