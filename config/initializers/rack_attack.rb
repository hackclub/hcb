# frozen_string_literal: true

class Rack::Attack
  ### Configure Cache ###

  # If you don't want to use Rails.cache (Rack::Attack's default), then
  # configure it here.
  #
  # Note: The store is only used for throttling (not blocklisting and
  # safelisting). It must implement .increment and .write like
  # ActiveSupport::Cache::Store

  # Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Safelist Hack Club Office
  safelist_ip(Rails.application.credentials.office_ip)

  # Get the IP addresses of stripe as an array
  stripe_ips_webhooks = Net::HTTP.get(URI("https://stripe.com/files/ips/ips_webhooks.txt")).split("\n")
  # Allow those IP addresses to send us as many webhooks as they like
  Rack::Attack.safelist("allow from Stripe (To Webhooks)") do |req|
    req.post? && stripe_ips_webhooks.include?(req.ip)
  end

  ### Throttle Spammy Clients ###

  # If any single client IP is making tons of requests, then they're
  # probably malicious or a poorly-configured scraper. Either way, they
  # don't deserve to hog all of the app server's CPU. Cut them off!
  #
  # Note: If you're serving assets through rack, those requests may be
  # counted by rack-attack and this throttle may be activated too
  # quickly. If so, enable the condition to exclude them from tracking.

  # Throttle all requests by IP (60rpm)
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:req/ip:#{req.ip}"
  throttle("req/ip", limit: 1000, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets") ||
                  req.path.start_with?("/admin") ||
                  req.path.start_with?("/stats")
  end

  ### Prevent Brute-Force Login Attacks ###

  # The most common brute-force login attack is a brute-force password
  # attack where an attacker simply tries a large number of emails and
  # passwords to see if any credentials match.
  #
  # Another common method of attack is to use a swarm of computers with
  # different IPs to try brute-forcing a password for a specific account.

  # Throttle POST requests to /login by IP address
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/ip:#{req.ip}"
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    if req.path == "/login" && req.post?
      req.ip
    end
  end

  # Throttle POST requests to /login by email param
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/email:#{normalized_email}"
  #
  # Note: This creates a problem where a malicious user could intentionally
  # throttle logins for another user and force their login requests to be
  # denied, but that's not very common and shouldn't happen to you. (Knock
  # on wood!)
  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/login" && req.post?
      # Normalize the email, using the same logic as your authentication process, to
      # protect against rate limit bypasses. Return the normalized email if present, nil otherwise.
      req.params["email"].to_s.downcase.gsub(/\s+/, "").presence
    end
  end

  ### Custom Throttle Response ###

  # By default, Rack::Attack returns an HTTP 429 for throttled responses,
  # which is just fine.
  #
  # If you want to return 503 so that the attacker might be fooled into
  # believing that they've successfully broken your app (or you just want to
  # customize the response), then uncomment these lines.
  # self.throttled_response = lambda do |env|
  #  [ 503,  # status
  #    {},   # headers
  #    ['']] # body
  # end
  #
  # Throttle POST requests to /donations/start/hq by IP address
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/ip:#{req.ip}"
  throttle("donations/start/ip", limit: 100, period: 20.seconds) do |req|
    if req.path.start_with?("/donations/start")
      req.ip
    end
  end

  throttle("donations/hq/ip", limit: 100, period: 20.seconds) do |req|
    if req.path.start_with?("/donations/hq")
      req.ip
    end
  end

  # Lockout IP addresses that are hammering your donation page.
  # After 5 requests in 30 seconds, block all requests from that IP for 3 hours.
  blocklist("allow2ban donation scrapers") do |req|
    # `filter` returns false value if request is to your donation page (but still
    # increments the count) so request below the limit are not blocked until
    # they hit the limit.  At that point, filter will return true and block.
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 100, findtime: 30.seconds, bantime: 3.minutes) do
      # The count for the IP is incremented if the return value is truthy.
      req.path.start_with?("/donations/start", "/donations/hq")
    end
  end

end

Rack::Attack.enabled = Rails.env.production? # only enable in production
