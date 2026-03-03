# frozen_string_literal: true

if Rails.env.production?
  require_relative "../../app/middleware/minify_html_middleware"
  Rails.application.middleware.use MinifyHtmlMiddleware
end
