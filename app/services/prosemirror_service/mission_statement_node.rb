# frozen_string_literal: true

module ProsemirrorService
  class MissionStatementNode < ProsemirrorToHtml::Nodes::Node
    include ApplicationHelper

    @node_type = "missionStatement"
    @tag_name = "blockquote"

    def tag
      [{ tag: self.class.tag_name, attrs: (@node.attrs.to_h || {}).merge({ class: "missionStatement py-2 my-2" }) }]
    end

    def matching
      @node.type == self.class.node_type
    end

    def text
      event = ProsemirrorService::Renderer.context.fetch(:event)

      AnnouncementsController.renderer.render partial: "announcements/nodes/mission_statement", locals: { mission: event.description }
    end

  end
end
