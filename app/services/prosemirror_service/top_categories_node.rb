# frozen_string_literal: true

module ProsemirrorService
  class TopCategoriesNode < ProsemirrorToHtml::Nodes::Node
    @node_type = "Announcement::Block::TopCategories"
    @tag_name = "div"

    def tag
      [{ tag: self.class.tag_name, attrs: @node.attrs.to_h || {} }]
    end

    def matching
      @node.type == self.class.node_type
    end

    def text
      ProsemirrorService::Renderer.render_node @node
    end

  end
end
