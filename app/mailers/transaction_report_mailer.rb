# frozen_string_literal: true

class TransactionReportMailer < ApplicationMailer
  def tell_zach
    target_users = User.where email: ["thomas@hackclub.com", "deet@hackclub.com", "amanda@hackclub.com", "dev@hackclub.com"]

    @target_users = target_users.map do |user|

      card_ids = user.stripe_cards.filter { |card| card.event.category != "salary" }.pluck(:stripe_id)

      cpts = CanonicalPendingTransaction.unsettled.joins(:raw_pending_stripe_transaction).where("(stripe_transaction->'card'->>'id' IN (?)) AND (CAST(stripe_transaction->>'created' AS BIGINT) >= EXTRACT(EPOCH FROM TIMESTAMP ?))", card_ids, 1.week.ago)
      cts = CanonicalTransaction.stripe_transaction.where("(stripe_transaction->'card'->>'id' IN (?)) AND (CAST(stripe_transaction->>'created' AS BIGINT) >= EXTRACT(EPOCH FROM TIMESTAMP ?))", card_ids, 1.week.ago)
      txs = cpts + cts

      total = txs.sum(&:amount_cents).abs

      { user:, txs:, total: }
    end.compact

    @total = @target_users.map{ |x| x[:txs].sum(&:amount_cents) }.sum.abs

    mail to: "zach@hackclub.com", subject: "Your weekly transaction report"
  end

end
