# frozen_string_literal: true

class StatsController < ApplicationController
  skip_after_action :verify_authorized
  skip_before_action :signed_in_user

  def project_stats
    slug = params[:slug]

    event = Event.find_by(is_public: true, slug:)

    return render plain: "404 Not found", status: :not_found unless event

    raised = event.canonical_transactions.revenue.sum(:amount_cents)

    render json: {
      raised:
    }
  end

  def stats_custom_duration
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : DateTime.new(2015, 1, 1)
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : DateTime.current

    render json: CanonicalTransactionService::Stats::During.new(start_time: start_date, end_time: end_date).run
  end

  def stats
    return render plain: "too many requests", status: :too_many_requests unless Flipper.enabled?(:stats_endpoint)

    json = Rails.cache.fetch("stats", expires_in: 1.hour, race_condition_ttl: 60 * 5) do
      now = params[:date].present? ? Date.parse(params[:date]) : DateTime.current
      year_ago = now - 1.year
      qtr_ago = now - 3.months
      month_ago = now - 1.month
      week_ago = now - 1.week

      events_list = Event.not_omitted
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
        events_count: Event.not_omitted
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

        # entire (all), year, quarter, and month time periods
        all: CanonicalTransactionService::Stats::During.new.run,
        last_year: CanonicalTransactionService::Stats::During.new(start_time: year_ago, end_time: now).run,
        last_qtr: CanonicalTransactionService::Stats::During.new(start_time: qtr_ago, end_time: now).run,
        last_month: CanonicalTransactionService::Stats::During.new(start_time: month_ago, end_time: now).run,
        last_week: CanonicalTransactionService::Stats::During.new(start_time: week_ago, end_time: now).run,

        # events
        events: events_list,

        # users

        currently_online: User.currently_online.count
      }
    end
    render json:
  end

  def admin_receipt_stats # secret api endpoint for the tv in the bank office
    users = [
      # These users are on the list because they're in HQ
      2189, # Caleb
      2046, # Mel
      2455, # Liv
      892,  # Max
      4059, # Daisy
      3851, # Arianna
      2232, # Sam
      5875, # Ben Dixon (@hackclub.com)
      5045, # Ben Dixon (@malted.dev)
      2501, # Ian
      5046, # Matt
      2468, # Lexi
      1328, # Sarthak
      7104, # Hunter
      8507, # Paul
      5855, # Zoya Hussain
      4282, # Sahiti Dasari
      5991, # Dieter Schoening
      4171, # B Smith
      5992, # NJOUONDO DJIMI JOSIAS AUREL
      5913, # Henry Bass
      6058, # Shubham Panth
      7368, # Kristina Hoadley
      5082, # Graham Darcey
      7114, # Jianmin Chen
      6678, # Shawn Malluwa-wadu
      5086, # Quillan George
      7545, # Faisal Ilyas Sayed
      4048, # Nila Ram
      5138, # Ruien Luo
      421,  # Zach Latta
      904,  # Christina Asquith
      595,  # Chris Walker
      2303, # Leo McElroy
      2596, # Deven Jadhav
      2779, # Judy Castillo
      2922, # Kara Massie
      3173, # Bence Beres
      1803, # Gary Tou
      1,    #   Zach Latta
      5670, # Thomas Stubblefield
      7873, # Cody Flaherty
      595,  # Chris Walker
      8823, # Lucy Tran
      8903, # Rhys Panopio
      3878, # Cheru
      12246, # Nora
      15136, # Zenab Hassan
      18300, # Alex Ren
      18746, # Jared Senesac
      16849, # Acon Lin
      21013, # Paolo Carino
    ]

    q = <<~SQL
      SELECT
        id,
        (
            SELECT COUNT(*) FROM hcb_codes
            INNER JOIN canonical_pending_transactions cpt ON cpt.hcb_code = hcb_codes.hcb_code
            INNER JOIN raw_pending_stripe_transactions rpst ON cpt.raw_pending_stripe_transaction_id = rpst.id
            INNER JOIN stripe_cardholders sc ON sc.stripe_id = rpst.stripe_transaction->'card'->'cardholder'->>'id'
            LEFT JOIN receipts ON receipts.receiptable_type = 'HcbCode' AND receipts.receiptable_id = hcb_codes.id
            LEFT JOIN canonical_pending_declined_mappings cpdm ON cpdm.canonical_pending_transaction_id = cpt.id
            INNER JOIN canonical_pending_event_mappings cpem ON cpem.canonical_pending_transaction_id = cpt.id
            INNER JOIN events ON events.id = cpem.event_id
            WHERE sc.user_id = users.id
            AND   receipts.id IS NULL AND cpdm.id IS NULL AND hcb_codes.marked_no_or_lost_receipt_at IS NULL
        )
      FROM users
      WHERE id IN (?)
      ORDER BY count DESC;
    SQL

    render json: User.find_by_sql([q, users])
  end

end
