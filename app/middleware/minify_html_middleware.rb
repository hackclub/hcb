# frozen_string_literal: true

require "minify_html"

class MinifyHtmlMiddleware
  # Safe options: strip comments and collapse whitespace, but never touch
  # attribute quotes, inline styles, or inline scripts. Keep type=text on
  # <input> so CSS attribute selectors (input[type="text"]) keep working.
  OPTS = {
    keep_spaces_between_attributes: true,
    keep_html_and_head_opening_tags: true,
    keep_input_type_text_attr: true,
    minify_css: true,
    minify_js: true,
    keep_comments: false
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    if headers["Content-Type"]&.include?("text/html")
      body = +""
      response.each { |part| body << part }
      response.close if response.respond_to?(:close)

      minified = minify_html(body, OPTS)
      headers["Content-Length"] = minified.bytesize.to_s
      [status, headers, [minified]]
    else
      [status, headers, response]
    end
  end

end
