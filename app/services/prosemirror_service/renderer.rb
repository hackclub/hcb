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

        unsanitized_html = <<-HTML.chomp
          <div class="pm-content">
            #{content}
          </div>
        HTML

        ActionController::Base.helpers.sanitize(unsanitized_html)
      end

      def create_renderer
        renderer = ProsemirrorToHtml::Renderer.new
        renderer.add_node ProsemirrorService::DonationGoalNode
        renderer.add_node ProsemirrorService::HcbCodeNode
        renderer.add_node ProsemirrorService::DonationSummaryNode
        renderer.add_node ProsemirrorService::TopMerchantsNode
        renderer.add_node ProsemirrorService::TopCategoriesNode
        renderer.add_node ProsemirrorService::TopTagsNode
        renderer.add_node ProsemirrorService::TopUsersNode

        renderer
      end

      def render_node(node)
        event = context.fetch(:event)
        is_email = context.fetch(:is_email)

        begin
          Announcement::Block.find(node.attrs.id).render(event:, is_email:)
        rescue ActiveRecord::RecordNotFound
          Announcements::BlocksController.renderer.render(partial: "announcements/blocks/unknown_block")
        end
      end

      def set_html(document, source_event: nil)
        map_nodes document do |node|
          if source_event.nil? && node["attrs"].present? && node["attrs"]["html"].present?
            node["attrs"].delete "html"
          elsif source_event.present? && node["attrs"].present? && node["attrs"]["id"].present?
            block = Announcement::Block.find(node["attrs"]["id"])
            node["attrs"]["html"] = block.render(event: source_event)
          end
        end
      end

      def block_ids(document)
        ids = []
        map_nodes document do |node|
          if node["attrs"].present? && node["attrs"]["id"].present?
            ids << node["attrs"]["id"]
          end
        end

        ids
      end

      def map_nodes(document, &block)
        document["content"] = document["content"].map { |node| map_node(node) { |inner| block.call(inner) } }

        document
      end

      private

      def map_node(node, &block)
        if node.is_a?(Hash)
          block.call(node)

          if node["content"].present?
            node["content"] = node["content"].map { |child| map_node(child) { |inner| block.call(inner) } }
          end
        end

        node
      end

    end

  end
end
