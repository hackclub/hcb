# frozen_string_literal: true

module OneTimeJobs
  class BackfillColumnTransferOnRawColumnTransactions
    extend Limiter::Mixin

    limit_method :perform, rate: 180 # 3 requests per second

    def self.perform
      raw_column_transactions = RawColumnTransaction.where(id: CanonicalTransaction.where(transaction_source_type: "RawColumnTransaction", hcb_code: HcbCode.where("hcb_code ILIKE 'HCB-000%'").select(:hcb_code)).select(:transaction_source_id), column_transfer: nil)

      raw_column_transactions.find_each(batch_size: 100) do |rct|
        process(rct)
      end
    end

    def self.process(raw_column_transaction)
      raw_column_transaction.extract_remote_object
    end

  end
end
