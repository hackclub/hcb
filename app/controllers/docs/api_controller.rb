# frozen_string_literal: true

module Docs
  class ApiController < ActionController::Base
    skip_before_action :verify_authenticity_token

    def v3
      # Renders the Stoplight viewer for our V3 API's Swagger docs
    end

  end
end
