# frozen_string_literal: true

require_relative "../../app/middleware/minify_html_middleware"

if Rails.env.production?
  Rails.application.middleware.use MinifyHtmlMiddleware
end
