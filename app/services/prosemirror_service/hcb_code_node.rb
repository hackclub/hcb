# frozen_string_literal: true

module ProsemirrorService
  class HcbCodeNode < ProsemirrorToHtml::Nodes::Node
    include ApplicationHelper

    @node_type = "hcbCode"
    @tag_name = "div"

    def tag
      [{ tag: self.class.tag_name, attrs: (@node.attrs.to_h || {}).merge({ class: "hcbCode relative card shadow-none border flex flex-col py-2 my-2" }) }]
    end

    def matching
      @node.type == self.class.node_type
    end

    def text
      event = ProsemirrorService::Renderer.context.fetch(:event)

      hcb_code = HcbCode.find_by_hashid(@node.attrs.code)

      AnnouncementsController.renderer.render partial: "announcements/nodes/hcb_code", locals: { hcb_code:, event: }
    end

  end
end
