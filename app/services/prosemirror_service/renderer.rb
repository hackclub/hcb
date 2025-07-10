# frozen_string_literal: true

module ProsemirrorService
  class Renderer
    class << self
      def render_html(json)
        @renderer ||= create_renderer

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
        renderer.add_node ProsemirrorService::DonationSummaryNode

        renderer
      end

    end

  end
end
