# frozen_string_literal: true

module ProsemirrorService
  class Renderer
    CONTEXT_KEY = :prosemirror_service_render_context

    class << self
      def with_context(new_context, &)
        old_context = context
        Fiber[CONTEXT_KEY] = new_context

        yield
      ensure
        Fiber[CONTEXT_KEY] = old_context
      end

      def context
        Fiber[CONTEXT_KEY]
      end

      def render_html(json, event, is_email: false)
        @renderer ||= create_renderer

        content = ""
        with_context({ event:, is_email: }) do
          content = @renderer.render json
        end

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
