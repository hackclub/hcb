# frozen_string_literal: true

# Facts about Hack Club the organization (as opposed to any single event/org in
# the app). See also HackClub::OrgChart for the HQ reporting structure.
module HackClub
  # Office IP addresses and CIDR ranges, from the OFFICE_IP credential, as IPAddr
  # objects. Used to safelist office traffic in Rack::Attack, which checks it on
  # every request, so the parsed result is memoized. The memo is keyed on the raw
  # credential so it re-parses if the value ever changes rather than going stale.
  # Malformed entries are skipped (and reported) so a single typo can't take down
  # every request that checks them.
  def self.office_ips
    raw = Credentials.fetch(:OFFICE_IP).to_s
    # Capture the memo in a local first. The previous version set
    # @office_ips_source before @office_ips, so a concurrent reader (this runs
    # in a Rack::Attack safelist on every request, under Puma's thread pool)
    # could see the matching source key while @office_ips was still nil and
    # return nil, crashing the safelist block on `nil.any?`. Requiring a
    # non-nil captured value closes that window.
    cached = @office_ips
    return cached if cached && @office_ips_source == raw

    parsed = raw.split(",").filter_map do |entry|
      office_ip = entry.strip
      ip = IPAddr.new(office_ip)
      # Reject a default route ("0.0.0.0/0", "::/0"). It would safelist the
      # entire internet, and since Rack::Attack safelists take precedence over
      # blocklists and throttles, that would also silently disable the
      # webhook-origin blocklists and login brute-force protection.
      if ip.prefix.zero?
        Rails.error.report(
          ArgumentError.new("overly-broad OFFICE_IP entry rejected"),
          context: { office_ip: }
        )
        next
      end

      ip
    rescue IPAddr::InvalidAddressError => e
      Rails.error.report(e, context: { office_ip: })
      nil
    end

    # Publish the parsed list before the source key so a racing reader that
    # observes the matching key also observes the populated list.
    @office_ips = parsed
    @office_ips_source = raw
    parsed
  end
end
