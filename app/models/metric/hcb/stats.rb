# frozen_string_literal: true

# == Schema Information
#
# Table name: metrics
#
#  id           :bigint           not null, primary key
#  metric       :jsonb
#  subject_type :string
#  type         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  subject_id   :bigint
#
# Indexes
#
#  index_metrics_on_subject                               (subject_type,subject_id)
#  index_metrics_on_subject_type_and_subject_id_and_type  (subject_type,subject_id,type) UNIQUE
#
class Metric
  module Hcb
    class Stats < Metric
      include AppWide

      def calculate
        now = DateTime.current
        year_ago = now - 1.year
        qtr_ago = now - 3.months
        month_ago = now - 1.month
        week_ago = now - 1.week
        day_ago = now - 1.day


        events_list = ::Event.not_omitted
                             .where("events.created_at <= ?", now)
                             .order(created_at: :desc)
                             .limit(10)
                             .pluck(:created_at)
                             .map(&:to_i)
                             .map { |time| { created_at: time } }

        tx_all = CanonicalTransaction.where.not("hcb_code LIKE 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::BANK_FEE_CODE}%'")
                                     .included_in_stats
                                     .where("date <= ?", now)

        pending_tx_all = CanonicalPendingTransaction.where(raw_pending_bank_fee_transaction_id: nil)
                                                    .included_in_stats
                                                    .unsettled
                                                    .and(CanonicalPendingTransaction.outgoing.or(CanonicalPendingTransaction.fronted))

        {
          date: now,
          events_count: ::Event.not_omitted
                               .not_hidden
                               .not_demo_mode
                               .approved
                               .where("events.created_at <= ?", now)
                               .count,
          last_transaction_date: tx_all.order(:date).last.date.to_time.to_i,

          # entire time period. this remains to prevent breaking changes to existing systems that use this endpoint
          raised: tx_all.revenue.sum(:amount_cents) + pending_tx_all.incoming.sum(:amount_cents),
          transactions_count: tx_all.size,
          transactions_volume: tx_all.sum("abs(amount_cents)") + pending_tx_all.sum("abs(amount_cents)"),

          # entire (all), year, quarter, month, week, and day time periods
          all: CanonicalTransactionService::Stats::During.new.run,
          last_year: CanonicalTransactionService::Stats::During.new(start_time: year_ago, end_time: now).run,
          last_qtr: CanonicalTransactionService::Stats::During.new(start_time: qtr_ago, end_time: now).run,
          last_month: CanonicalTransactionService::Stats::During.new(start_time: month_ago, end_time: now).run,
          last_week: CanonicalTransactionService::Stats::During.new(start_time: week_ago, end_time: now).run,
          last_day: CanonicalTransactionService::Stats::During.new(start_time: day_ago, end_time: now).run,

          # events
          events: events_list,

          # users

          currently_online: ::User.currently_online.count
        }
      end

    end
  end

end
