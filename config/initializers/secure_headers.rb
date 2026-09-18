# frozen_string_literal: true

# `'unsafe-inline'` and `'unsafe-eval'` are currently required and cannot be
# dropped without a sizable refactor:
#   * style-src  'unsafe-inline' — inline `style=` attributes throughout, and
#     Stripe Elements and Plaid Link both inject inline styles.
#   * script-src 'unsafe-inline' — inline bootstrap scripts (Plaid, HelpScout,
#     Plausible, FullStory) and Alpine.js `x-*`/`@click` attribute handlers.
#   * script-src 'unsafe-eval'   — Alpine.js evaluates its directive
#     expressions with `new Function(...)`.
#
# Ships report-only: nothing is blocked until CSP_ENFORCE=true. Once reports are
# quiet, flip the default below rather than relying on the variable forever.
# CSP_REPORTING=off drops the report-uri directive without a deploy.

asset_hosts = Array(ENV["ASSET_HOST"].presence)

# Both endpoint shapes: the SDK uses the global one on us-east-1 (what production
# emits today) and the regional one everywhere else.
s3_bucket = Credentials.fetch(:S3, :BUCKET).presence
s3_region = Credentials.fetch(:S3, :REGION).presence
s3_hosts = [
  ("https://#{s3_bucket}.s3.amazonaws.com" if s3_bucket),
  ("https://#{s3_bucket}.s3.#{s3_region}.amazonaws.com" if s3_bucket && s3_region),
].compact

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
    https://docuseal.com https://cdn.docuseal.com
    https://challenges.cloudflare.com
    https://beacon-v2.helpscout.net
    https://plausible.io
    https://edge.fullstory.com https://rs.fullstory.com
    https://www.youtube.com
    https://unpkg.com
    https://cdnjs.cloudflare.com
    https://cdn.jsdelivr.net
  ] + asset_hosts,

  style_src: ["'self'", "'unsafe-inline'"] + %w[
    https://fonts.googleapis.com
    https://cdnjs.cloudflare.com
    https://cdn.jsdelivr.net
    https://unpkg.com
  ] + asset_hosts,

  font_src: ["'self'", "data:"] + %w[https://fonts.gstatic.com https://assets.hackclub.com https://docuseal.co https://unpkg.com] + asset_hosts,

  # Blanket https: — images come from too many CDNs and user uploads to enumerate.
  img_src: ["'self'", "data:", "blob:", "https:"],

  connect_src: ["'self'"] + %w[
    https://api.stripe.com https://m.stripe.network https://r.stripe.com https://*.js.stripe.com
    https://link.com https://*.link.com
    https://*.plaid.com
    https://docuseal.com https://docuseal.co https://cdn.docuseal.com
    https://appsignal-endpoint.net
    https://challenges.cloudflare.com
    https://beaconapi.helpscout.net https://chatapi.helpscout.net wss://chatapi.helpscout.net
    https://*.fullstory.com wss://*.fullstory.com
    https://blog.hcb.hackclub.com https://icons.hackclub.com https://assets.hackclub.com
    https://*.cloudfront.net
    https://cdn.jsdelivr.net
    https://plausible.io
  ] + asset_hosts + s3_hosts, # s3: ActiveStorage direct uploads PUT to the presigned URL

  frame_src: ["'self'"] + %w[
    https://js.stripe.com https://*.js.stripe.com https://hooks.stripe.com https://checkout.stripe.com
    https://link.com https://*.link.com
    https://cdn.plaid.com https://*.plaid.com
    https://docuseal.com https://docuseal.co https://cdn.docuseal.com
    https://challenges.cloudflare.com
    https://www.youtube.com https://www.youtube-nocookie.com
    https://*.hackclub.com
    https://links.taxbandits.io https://testlinks.taxbandits.io
  ] + s3_hosts, # s3: receipt preview iframes use a self path that 302s to S3

  worker_src: ["'self'", "blob:"],
}

# Browsers stop sending reports when the directive goes away, so this is the
# no-deploy lever if report volume becomes a problem.
if ENV["CSP_REPORTING"] != "off"
  csp[:report_uri] = [Rails.configuration.constants[:csp_violation_report_path]]
end

if Rails.env.development?
  localhost = %w[http://localhost:* http://127.0.0.1:*]
  csp[:connect_src] += localhost + %w[ws://localhost:* ws://127.0.0.1:*]
  csp[:frame_src]   += localhost
end

enforce = ENV["CSP_ENFORCE"] == "true"

SecureHeaders::Configuration.default do |config|
  # HSTS comes from config.force_ssl; cookie flags are Rails' job.
  config.hsts    = SecureHeaders::OPT_OUT
  config.cookies = SecureHeaders::OPT_OUT

  config.x_frame_options        = "SAMEORIGIN"
  config.x_content_type_options = "nosniff"
  config.referrer_policy        = "strict-origin-when-cross-origin"

  config.csp             = enforce ? csp : SecureHeaders::OPT_OUT
  config.csp_report_only = enforce ? SecureHeaders::OPT_OUT : csp
end
