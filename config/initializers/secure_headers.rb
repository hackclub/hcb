# frozen_string_literal: true

# Be sure to restart your server when you modify this file.
#
# Security response headers for HCB, configured with the `secure_headers` gem
# (https://github.com/github/secure_headers). This owns the Content Security
# Policy plus a few companion headers (X-Frame-Options, X-Content-Type-Options,
# Referrer-Policy).
#
# HSTS and cookie flags are intentionally opted out here: Rails' `force_ssl`
# (config/environments/production.rb, staging.rb) already emits
# Strict-Transport-Security and marks cookies `secure`, so we leave those to
# Rails rather than have two layers fight over the same headers.
#
# The CSP allow-lists every third-party origin the front-end actually loads
# from (Stripe, Plaid, Docuseal, Cloudflare Turnstile, HelpScout, Plausible,
# YouTube, Google Fonts, the various Hack Club CDNs, ...). When you add an
# integration that loads a script/iframe/font or makes a cross-origin request,
# add its origin to the relevant directive or the browser will block it.
#
# `'unsafe-inline'` and `'unsafe-eval'` are currently required and cannot be
# dropped without a sizable refactor:
#   * style-src 'unsafe-inline'  — hundreds of inline `style="..."` attributes
#     (nonces/hashes cannot cover inline style attributes).
#   * script-src 'unsafe-inline' — inline bootstrap scripts (Plaid, HelpScout,
#     Plausible) and Alpine.js `x-*`/`@click` attribute handlers, which CSP
#     treats as inline script and which nonces cannot cover.
#   * script-src 'unsafe-eval'   — Alpine.js evaluates its directive
#     expressions with `new Function(...)`.
#
# Rollout: deploy first with `CSP_REPORT_ONLY=true`. In Report-Only mode the
# policy blocks nothing; violations only surface in each browser's devtools
# console, so walk the key flows (login, donations, card reveal, OAuth authorize,
# HelpScout), confirm nothing legitimate is flagged, then unset it to enforce.

# When assets are served from a CDN (config.asset_host), that origin serves our
# JS/CSS/fonts and must be allow-listed wherever those load from.
asset_host = ENV["ASSET_HOST"].presence

# ActiveStorage serves uploads (receipts, avatars, ...) in redirect mode, so a
# same-origin blob URL 302s to the S3 bucket's virtual-hosted host. Browsers
# re-check CSP against the redirect target, so the bucket host must be allowed
# for the iframes that preview receipts/PDFs (images already allow any https:).
# Read the same S3 config storage.yml uses; Credentials (required in
# config/application.rb) covers both ENV and Rails' encrypted credentials.
s3_bucket = Credentials.fetch(:S3, :BUCKET).presence
s3_region = Credentials.fetch(:S3, :REGION).presence
s3_host = ("https://#{s3_bucket}.s3.#{s3_region}.amazonaws.com" if s3_bucket && s3_region)

# CSP keyword sources must keep their surrounding single quotes, so they are
# written as plain quoted strings ('self', 'unsafe-inline', ...) rather than in
# a %w[] array (which would swallow the quotes). Scheme sources (data:, blob:,
# https:) and host sources need no quotes.
csp = {
  # Keep the `https://` scheme on sources instead of letting the gem strip it.
  preserve_schemes: true,

  default_src: ["'self'"],
  base_uri: ["'self'"],
  object_src: ["'none'"],
  form_action: ["'self'"],
  frame_ancestors: ["'self'"], # donation pages relax this per-action

  script_src: ["'self'", "'unsafe-inline'", "'unsafe-eval'"] + %w[
    https://js.stripe.com https://*.js.stripe.com https://m.stripe.network
    https://cdn.plaid.com
    https://cdn.docuseal.com
    https://challenges.cloudflare.com
    https://beacon-v2.helpscout.net
    https://plausible.io
    https://www.youtube.com
    https://unpkg.com
    https://cdnjs.cloudflare.com
    https://cdn.jsdelivr.net
  ] + Array(asset_host),

  style_src: ["'self'", "'unsafe-inline'"] + %w[
    https://fonts.googleapis.com
    https://cdnjs.cloudflare.com
    https://unpkg.com
  ] + Array(asset_host),

  font_src: ["'self'", "data:"] + %w[
    https://fonts.gstatic.com
    https://assets.hackclub.com
    https://d3hb14vkzrxvla.cloudfront.net
  ] + Array(asset_host),

  # Images come from many Hack Club CDNs, Gravatar, Giphy, S3 receipts, etc.,
  # and the list changes often; allow any HTTPS image (plus data:/blob: for QR
  # codes and client-generated previews) rather than an ever-stale list.
  img_src: ["'self'", "data:", "blob:", "https:"],

  connect_src: ["'self'"] + %w[
    https://api.stripe.com https://m.stripe.network https://r.stripe.com https://*.js.stripe.com
    https://*.plaid.com
    https://appsignal-endpoint.net
    https://challenges.cloudflare.com
    https://*.helpscout.net wss://*.helpscout.net https://d3hb14vkzrxvla.cloudfront.net
    https://plausible.io
    https://cdn.jsdelivr.net
    https://blog.hcb.hackclub.com
  ] + Array(asset_host),

  frame_src: ["'self'"] + %w[
    https://js.stripe.com https://*.js.stripe.com https://hooks.stripe.com https://checkout.stripe.com
    https://cdn.plaid.com https://*.plaid.com
    https://docuseal.com https://cdn.docuseal.com
    https://challenges.cloudflare.com
    https://www.youtube.com https://www.youtube-nocookie.com
    https://blog.hcb.hackclub.com
    https://links.taxbandits.io https://testlinks.taxbandits.io
  ] + Array(s3_host),

  # Some libraries (html-to-image, AppSignal) spin up blob-backed workers.
  worker_src: ["'self'", "blob:"],
}

# In development, allow any local dev server on any localhost port (the blog
# widget's iframe + unread-count fetch, asset/HMR servers, etc.). The `:*` port
# wildcard is required — a bare host only matches the scheme's default port.
if Rails.env.development?
  localhost = %w[http://localhost:* http://127.0.0.1:*]
  csp[:connect_src] += localhost + %w[ws://localhost:* ws://127.0.0.1:*]
  csp[:frame_src]   += localhost
end

report_only = ENV["CSP_REPORT_ONLY"].present?

SecureHeaders::Configuration.default do |config|
  # Rails' force_ssl already manages these; don't emit them twice.
  config.hsts    = SecureHeaders::OPT_OUT
  config.cookies = SecureHeaders::OPT_OUT

  config.x_frame_options        = "SAMEORIGIN"
  config.x_content_type_options = "nosniff"
  config.referrer_policy        = "strict-origin-when-cross-origin"

  if report_only
    config.csp             = SecureHeaders::OPT_OUT
    config.csp_report_only = csp
  else
    config.csp             = csp
    config.csp_report_only = SecureHeaders::OPT_OUT
  end
end
