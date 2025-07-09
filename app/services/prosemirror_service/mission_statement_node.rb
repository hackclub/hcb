# frozen_string_literal: true

module ProsemirrorService
  class MissionStatementNode < ProsemirrorToHtml::Nodes::Node
    @node_type = "missionStatement"
    @tag_name = "p"

    def tag
      [{ tag: self.class.tag_name, attrs: (@node.attrs || {}).merge({ class: "missionStatement p-1 bg-white border-2 border-black border-solid dark:bg-black rounded-md italic" }) }]
    end

    def matching
      @node.type == self.class.node_type
    end

    def text
      ProsemirrorService::Renderer.event.description
    end

  end
end
