# frozen_string_literal: true

# Requests reach Puma through the Hetzner load balancer and then Caddy. Both set
# X-Forwarded-*; neither sets, or strips, the RFC 7239 `Forwarded:` header.
# Rack reads `Forwarded:` first by default, and when it's present ignores
# X-Forwarded-For entirely, so a client sending `Forwarded: for=<any ip>` would
# pick its own `request.ip`, and its own `request.remote_ip` too, since
# ActionDispatch::RemoteIp builds on Rack's `forwarded_for`. That breaks every
# IP-keyed safelist and throttle in config/initializers/rack_attack.rb. Only
# trust the headers our proxies set.
Rack::Request.forwarded_priority = [:x_forwarded]
