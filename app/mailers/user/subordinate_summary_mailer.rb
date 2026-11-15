# frozen_string_literal: true

class User
  class SubordinateSummaryMailer < ApplicationMailer
    def weekly(manager:, subordinates:)
      @manager = manager
      @subordinates = subordinates

      @subordinate_stats = subordinates.map { |subordinate| user_stats(subordinate) }

      mail to: manager.email, subject: "Your weekly direct report transaction summary"
    end

    private

    def user_stats(user, since: 1.week.ago)
      card_ids = user.stripe_cards.includes(event: :plan).where.not(plan: { type: Event::Plan::SalaryAccount.name }).pluck(:stripe_id)

      cpts = CanonicalPendingTransaction.unsettled.joins(:raw_pending_stripe_transaction).where("(stripe_transaction->'card'->>'id' IN (?)) AND (CAST(stripe_transaction->>'created' AS BIGINT) >= ?)", card_ids, since.to_i)
      cts = CanonicalTransaction.stripe_transaction.where("(stripe_transaction->'card'->>'id' IN (?)) AND (CAST(stripe_transaction->>'created' AS BIGINT) >= ?)", card_ids, since.to_i)
      hcb_codes = HcbCode.where(hcb_code: cpts.pluck(:hcb_code) + cts.pluck(:hcb_code))

      OpenStruct.new(
        {
          user:,
          total_cents: hcb_codes.sum(&:amount_cents),
          hcb_codes:
        }
      )
    end

  end

end
