# frozen_string_literal: true

module OneTimeJobs
  class BackfillLocalObjectOnRawColumnTransactions
    def self.perform
      raw_column_transactions = RawColumnTransaction.where(id: CanonicalTransaction.where(transaction_source_type: "RawColumnTransaction", hcb_code: HcbCode.where("hcb_code ILIKE 'HCB-000%'").select(:hcb_code)).select(:transaction_source_id))

      raw_column_transactions.find_each(batch_size: 100) do |rct|
        rct.extract_remote_object
      end
    end

  end
end
