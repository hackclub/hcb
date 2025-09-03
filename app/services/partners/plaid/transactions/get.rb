# frozen_string_literal: true

module Partners
  module Plaid
    module Transactions
      class Get
        DATE_FORMAT = "%Y-%m-%d"
        COUNT = 500

        include ::Partners::Plaid::Shared::Client

        def initialize(bank_account_id:, start_date:, end_date:)
          @bank_account_id = bank_account_id

          @start_date = start_date || (Date.today - 5.years).strftime(::Partners::Plaid::Transactions::Get::DATE_FORMAT)
          @end_date = end_date || (Date.today + 2.days).strftime(::Partners::Plaid::Transactions::Get::DATE_FORMAT)
        end

        def run
          plaid_transactions
        end

        private

        def plaid_transactions
          resp = fetch_transactions
          ts = resp.transactions

          while ts.length < resp.total_transactions
            resp = fetch_transactions(offset: ts.length)
            ts += resp.transactions
          end

          ts
        end

        def fetch_transactions(offset: 0)
          begin
            request = ::Plaid::TransactionsGetRequest.new(
              access_token:,
              start_date: @start_date,
              end_date: @end_date,
              options: {
                offset:,
                count: COUNT,
                account_ids:,
              },
            )

            results = plaid_client.transactions_get(request)

            Rails.logger.info "plaid_client.transaction.get start_date=#{@start_date} end_date=#{@end_date} offset=#{offset} count=#{COUNT} account_ids=#{account_ids} total_transactions=#{results.total_transactions}"

            mark_plaid_item_success!

            results
          rescue ::Plaid::ApiError => e
            Rails.error.report(e, context: { message: "plaid_client.transactions.get failed for bank_account #{bank_account.id} with access token #{access_token}." })

            mark_plaid_item_failed!

            raise
          end
        end

        def access_token
          @access_token ||= bank_account.plaid_access_token
        end

        def mark_plaid_item_failed!
          bank_account.touch(:failed_at) # mark plaid item failed
          bank_account.increment!(:failure_count)
        end

        def mark_plaid_item_success!
          bank_account.update_column(:failed_at, nil)
          bank_account.update_column(:failure_count, 0)
        end

        def account_ids
          [bank_account.plaid_account_id]
        end

        def bank_account
          @bank_account ||= BankAccount.find(@bank_account_id)
        end

      end
    end
  end
end
