# frozen_string_literal: true

class TransactionReportMailer < ApplicationMailer
  def tell_zach
    target_users = User.where email: %w[
      dev@hackclub.com
      alexren@hackclub.com
      melanie@hackclub.com
      malted@hackclub.com
      jared@hackclub.com
      graham@hackclub.com
    ]

    @target_users = target_users.map do |user|

      card_ids = user.stripe_cards.filter { |card| card.event.category != "salary" }.pluck(:stripe_id)

      cpts = CanonicalPendingTransaction.unsettled.joins(:raw_pending_stripe_transaction).where("(stripe_transaction->'card'->>'id' IN (?)) AND (CAST(stripe_transaction->>'created' AS BIGINT) >= ?)", card_ids, 1.week.ago.to_i)
      cts = CanonicalTransaction.stripe_transaction.where("(stripe_transaction->'card'->>'id' IN (?)) AND (CAST(stripe_transaction->>'created' AS BIGINT) >= ?)", card_ids, 1.week.ago.to_i)
      txs = cpts + cts

      total = txs.sum(&:amount_cents).abs

      { user:, txs:, total: }
    end.compact

    @total = @target_users.map { |x| x[:txs].sum(&:amount_cents) }.sum.abs

    mail to: "zach@hackclub.com", subject: "Your weekly transaction report"
  end

end
