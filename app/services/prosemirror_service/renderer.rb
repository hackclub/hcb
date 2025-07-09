# frozen_string_literal: true

module ProsemirrorService
  class Renderer
    class << self
      attr_reader :event

      def render_html(json, event)
        @renderer ||= create_renderer
        @event = event

        @renderer.render JSON.parse(json)
      end

      def create_renderer
        renderer = ProsemirrorToHtml::Renderer.new
        renderer.add_node ProsemirrorService::MissionStatementNode
        renderer.add_node ProsemirrorService::DonationGoalNode

        renderer
      end

    end

  end
end
