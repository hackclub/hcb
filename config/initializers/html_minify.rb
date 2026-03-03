# frozen_string_literal: true

if Rails.env.production?
  require "htmlcompressor"
  Rails.application.middleware.use HtmlCompressor::Rack,
                                   remove_intertag_spaces: true,
                                   remove_comments: true,
                                   remove_multi_spaces: true,
                                   remove_quotes: true
end
