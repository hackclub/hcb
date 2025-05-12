# What happens when you type `hcb.hackclub.com`

This is a play on the classic interview question "What happens when you type
google.com", with a focus on the HCB-specific aspects of production deployment.

The goal of this document is to help engineers understand how our production
environment is configured.

1. You type `hcb.hackclub.com` into your browser.
2. Your device performs a DNS lookup.
    - Hack Club's DNS for `hackclub.com` (and other domains) is served
      by [DNSimple](https://dnsimple.com/), and configured
      at [https://github.com/hackclub/dns](https://github.com/hackclub/dns)
    - `hcb.hackclub.com` is an `A` record to our Hetzner load balancer
3. Your browser opens a TCP socket and does all the TLS/HTTPS handshake stuff.
   Since it's not unique/specific to HCB, I'm not going to cover that here.
4. The Hetzner load balancer receives your request.
    - The load balancer has been configured to terminate SSL. If the request is
      HTTP, it will be automatically redirected to HTTPS by the LB.
    - The LB forwards (reverse proxy) your request to one the app servers as
      HTTP. Everything behind the LB is HTTP. App servers are not directly
      accessible the public internet, so this is fine. LB uses least-connection
      algorithm, but can also be configured to be round-robin. The LB is able to
      access the app servers because they are on the same private Hetzner
      network.
5. The Caddy on the app server receives the forwarded request.
    - Caddy honestly isn't necessary here, but is provided as default
      configuration by Hatchbox.
    - Caddy forwards the request to Puma (the web server the Rails uses).
6. From here, it's pretty standard Rails stuff. Puma receives the requests and
   builds an `Env` obj. That Env object is passed through the Rack middlewares
   and is processed by Rails.

If you'd like more details, [deployment.md](deployment.md) provide more of a
runbook style guide for how our production deployment is setup.

~ [@garyhtou](https://garytou.com)
