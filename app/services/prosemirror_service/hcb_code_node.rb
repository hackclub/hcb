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
      is_email = ProsemirrorService::Renderer.context.fetch(:is_email)

      hcb_code = HcbCode.find_by_hashid(@node.attrs.code)

      unless hcb_code.event == event
        hcb_code = nil
      end

      AnnouncementsController.renderer.render partial: "announcements/nodes/hcb_code", locals: { hcb_code:, event:, is_email: }
    end

  end
end
