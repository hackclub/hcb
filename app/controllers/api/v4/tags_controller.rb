# frozen_string_literal: true

module Api
  module V4
    class TagsController < ApplicationController
      include SetEvent

      before_action :set_api_event

      def index
        @tags = @event.tags.order(created_at: :desc)
      end

    end
  end
end
