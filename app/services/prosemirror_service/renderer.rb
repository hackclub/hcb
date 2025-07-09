# frozen_string_literal: true

module ProsemirrorService
  class Renderer
    class << self
      attr_reader :event

      def render_html(json, event)
        @renderer ||= create_renderer
        @event = event

        content = @renderer.render JSON.parse(json)

        <<-HTML.chomp
          <div class="pm-content">
            #{content}
          </div>
        HTML
      end

      def create_renderer
        renderer = ProsemirrorToHtml::Renderer.new
        renderer.add_node ProsemirrorService::DonationGoalNode
        renderer.add_node ProsemirrorService::HcbCodeNode

        renderer
      end

    end

  end
end
