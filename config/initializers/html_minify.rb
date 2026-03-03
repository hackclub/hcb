# frozen_string_literal: true

if Rails.env.production?
  Rails.application.middleware.use MinifyHtmlMiddleware
end
