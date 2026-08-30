# frozen_string_literal: true

# Restart server when modifying file

# `'unsafe-inline'` and `'unsafe-eval'` are currently required and cannot be
# dropped without a sizable refactor:
#   * we should allow inline styling
#   * script-src 'unsafe-inline' — inline bootstrap scripts (Plaid, HelpScout,
#     Plausible) and Alpine.js `x-*`/`@click` attribute handlers, which CSP
#   * script-src 'unsafe-eval'   — Alpine.js evaluates its directive
#     expressions with `new Function(...)`.
#
# Rollout: deploy first with `CSP_REPORT_ONLY=true` so violations are reported
# (in Report-Only mode) but not enforced; confirm nothing legitimate is blocked,
# then unset it to enforce.

asset_host = ENV["ASSET_HOST"].presence

s3_bucket = ENV["S3__BUCKET"].presence
s3_region = ENV["S3__REGION"].presence
s3_host = ("https://#{s3_bucket}.s3.#{s3_region}.amazonaws.com" if s3_bucket && s3_region)

csp = {
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

  font_src: ["'self'", "data:"] + %w[https://fonts.gstatic.com https://assets.hackclub.com] + Array(asset_host),

  # Images come from many Hack Club CDNs, Gravatar, Giphy, S3 receipts, etc.,
  img_src: ["'self'", "data:", "blob:", "https:"],

  connect_src: ["'self'"] + %w[
    https://api.stripe.com https://m.stripe.network https://r.stripe.com https://*.js.stripe.com
    https://*.plaid.com
    https://appsignal-endpoint.net
    https://challenges.cloudflare.com
    https://beaconapi.helpscout.net https://chatapi.helpscout.net
    https://*.cloudfront.net
    https://cdn.jsdelivr.net
    https://plausible.io
  ] + Array(asset_host),

  frame_src: ["'self'"] + %w[
    https://js.stripe.com https://*.js.stripe.com https://hooks.stripe.com https://checkout.stripe.com
    https://cdn.plaid.com https://*.plaid.com
    https://docuseal.com https://cdn.docuseal.com
    https://challenges.cloudflare.com
    https://www.youtube.com https://www.youtube-nocookie.com
    https://*.hackclub.com
    https://links.taxbandits.io https://testlinks.taxbandits.io
  ] + Array(s3_host),

  worker_src: ["'self'", "blob:"],
}

# blogs run on different port, see blog_controller.js
if Rails.env.development?
  csp[:connect_src] += %w[http://localhost:3001]
  csp[:frame_src]   += %w[http://localhost:3001]
end

SecureHeaders::Configuration.default do |config|
  config.hsts    = SecureHeaders::OPT_OUT
  config.cookies = SecureHeaders::OPT_OUT

  config.x_frame_options        = "SAMEORIGIN"
  config.x_content_type_options = "nosniff"
  config.referrer_policy        = "strict-origin-when-cross-origin"

  config.csp             = csp
  config.csp_report_only = SecureHeaders::OPT_OUT
end
