# frozen_string_literal: true

module DonationService
  class Donors
    TOP_LIMIT = 10  # three go on the podium, the rest are listed underneath it
    TOP_MINIMUM = 3 # the podium needs three places

    RECENT_LIMIT = 8
    RECENT_MINIMUM = 8

    EMAIL = "COALESCE(recurring_donations.email, NULLIF(donations.email, ''))"

    IDENTITY = "COALESCE(#{EMAIL}, 'donation-' || donations.id::text)".freeze

    DONATED_AT = "COALESCE(donations.in_transit_at, donations.created_at)"

    # A group's most recent donation, which is the one we display it as.
    REPRESENTATIVE = "(ARRAY_AGG(donations.id ORDER BY #{DONATED_AT} DESC))[1]".freeze

    TopDonor = Struct.new(:name, :amount)

    def initialize(event)
      @event = event
    end

    def top
      totals = donations.where(anonymous: false)
                        .where("#{EMAIL} IS NOT NULL")
                        .group(Arel.sql(EMAIL))
                        .order(Arel.sql("SUM(donations.amount) DESC"))
                        .limit(TOP_LIMIT)
                        .pluck(Arel.sql(REPRESENTATIVE), Arel.sql("SUM(donations.amount)"))
                        .to_h

      donors = load(totals.keys).map { |donation| TopDonor.new(donation.name, totals[donation.id]) }

      at_least(donors.sort_by { |donor| -donor.amount }, TOP_MINIMUM)
    end

    def recent
      ids = donations.group(Arel.sql(IDENTITY))
                     .order(Arel.sql("MAX(#{DONATED_AT}) DESC"))
                     .limit(RECENT_LIMIT)
                     .pluck(Arel.sql(REPRESENTATIVE))

      at_least(load(ids).sort_by(&:donated_at).reverse, RECENT_MINIMUM)
    end

    private

    def donations
      @event.donations.left_joins(:recurring_donation).succeeded_and_not_refunded
    end

    def load(ids)
      Donation.includes(:recurring_donation).where(id: ids).to_a
    end

    def at_least(donors, minimum)
      donors.size < minimum ? [] : donors
    end

  end

end
