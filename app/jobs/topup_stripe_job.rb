# frozen_string_literal: true

class TopupStripeJob < ApplicationJob
  queue_as :default

  # Don't retry jobs w/ balance anomalies, reattempt at next run
  discard_on(Errors::StripeIssuingBalanceAnomaly) do |job, error|
    Airbrake.notify(error)
  end

  def perform
    # Stripe requires us to keep a certain amount of money in our Stripe Issuing
    # Balance in order to approve card authorizations. The "buffer" is the
    # amount of floating money that should be in Stripe at any given time.
    #
    # As of Jan 2024, our maximum Stripe issuing spending in a given week is
    # $95k (week of Oct 1st, 2023). We want to have a buffer of double the
    # expected max weekly spending. The week time-frame is important because it
    # can take 5 business days for Top-ups to become available.
    # ref: https://hcb.hackclub.com/blazer/queries/487-stripe-issuing-spending-per-week
    #
    # Having this buffer (double the max weekly spending) means the "age" of our
    # money on Stripe Issuing is at least two weeks.
    # Ex. The money from a top-up today will be spent in no earlier than two
    #     weeks from now (FIFO order).
    buffer = 200_000 * 100

    # amount of money currently in stripe
    balances = StripeService::Balance.retrieve
    pending = balances[:issuing].try(:[], :pending).try(:[], 0).try(:[], :amount) || 0 # new API changed this - it is not included when 0
    available = balances[:issuing][:available][0][:amount]

    if available > buffer * 1.5
      # Something is likely wrong if our Stripe Issuing balance is greater than
      # the buffer by a significant amount. This could be a sign that this job
      # is not computing the top-up amount correctly.
      #
      # NOTE: It is possible to have an issuing balance higher than the buffer
      # due to `expected_tx_sum`. However, it should only be a marginal amount.
      raise Errors::StripeIssuingBalanceAnomaly, <<~MSG.squish
        Stripe Issuing balance anomaly: We're trying to top-up, but found the
        balance is already unexpectedly high.
        Available: #{available},
        Buffer: #{buffer}
      MSG
    elsif available < buffer / 2
      # It appears we're spending our top-up money too quickly. Our ideal "age"
      # of money is at least two weeks (see above). This notification is a sign
      # we may need to increase our buffer.
      Airbrake.notify(<<~MSG.squish)
        Stripe Issuing balance: Low age of money.
        We only have #{ActionController::Base.helpers.number_to_percentage((available / buffer.to_f) * 100, precision: 2)}
        of the buffer available for spending.
        Available: #{available}
      MSG
    end

    # amount of money already enroute to stripe through existing topups
    topups = Stripe::Topup.list(status: :pending).auto_paging_each.filter do |t|
      t.destination_balance == "issuing"
    end
    enroute_sum = topups.sum(&:amount)

    # stripe TXs can get created 1 to 30 days after approval, so let's grab any
    # authorization that's pending
    expected_tx_sum = 0
    authorizations = StripeService::Issuing::Authorization.list(status: :pending)
    authorizations.auto_paging_each do |auth|
      expected_tx_sum += auth[:amount] if auth[:approved] &&
                                          auth[:transactions].empty?
    end

    topup_amount = buffer - pending - available - enroute_sum + expected_tx_sum
    # 200k - (current + pending + en route balance) + (expected_tx_sum)

    StatsD.gauge("stripe_issuing_expected_tx_sum", expected_tx_sum, sample_rate: 1.0)
    StatsD.gauge("stripe_issuing_enroute_issuing_topups_sum", enroute_sum, sample_rate: 1.0)
    StatsD.gauge("stripe_issuing_available_issuing_balance", available, sample_rate: 1.0)
    StatsD.gauge("stripe_issuing_pending_issuing_balance", pending, sample_rate: 1.0)

    puts "topup amount == #{topup_amount}"
    return unless topup_amount >= 5_000 * 100

    # The maximum amount for a single top-up is $300k
    # ref: https://github.com/hackclub/hcb/issues/4462#issuecomment-1917940104
    limited_topup_amount = topup_amount.clamp(0, 300_000 * 100)

    StripeService::Topup.create(
      destination_balance: "issuing",
      amount: limited_topup_amount,
      currency: "usd",
      statement_descriptor: "Stripe Top-up"
    )

    puts "Just created a topup for #{limited_topup_amount}"

    StatsD.increment("stripe_issuing_topup", limited_topup_amount)
  end

end
