# frozen_string_literal: true

# The reverse proxy in front of the app (Caddy) gzips every response. Compressing
# HTML that reflects both user input and per-request secrets is what makes the
# BREACH attack (CVE-2013-3587) possible, and it is flagged on every PCI scan.
# `Cache-Control: no-transform` tells the proxy to pass these responses through
# uncompressed; assets and API responses keep their compression.
class NoTransformHtml
  HTML_TYPES = ["text/html", "text/vnd.turbo-stream.html"].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    if html?(headers[Rack::CONTENT_TYPE])
      directives = headers[Rack::CACHE_CONTROL].to_s.split(",").map(&:strip).reject(&:empty?)
      directives << "no-transform" unless directives.include?("no-transform")
      headers[Rack::CACHE_CONTROL] = directives.join(", ")
    end

    [status, headers, body]
  end

  private

  def html?(content_type)
    content_type.to_s.start_with?(*HTML_TYPES)
  end

end
