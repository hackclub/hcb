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

            guessed_event_id = hcb_code.event.try(:id)
            next unless guessed_event_id

            guessed_subledger_id = hcb_code.ct&.canonical_event_mapping&.subledger_id

            ActiveRecord::Base.transaction do
              ct.update_column(:hcb_code, hcb_code.hcb_code)

              attrs = {
                canonical_transaction_id: ct.id,
                event_id: guessed_event_id,
                subledger_id: guessed_subledger_id
              }
              ::CanonicalEventMapping.create!(attrs)
            end
          end
        end

        private

        def unmapped_short_codes
          ::CanonicalTransaction.unmapped.with_short_code.order("date asc")
        end

      end
    end
  end
end
