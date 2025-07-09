# frozen_string_literal: true

module ProsemirrorService
  class DonationGoalNode < ProsemirrorToHtml::Nodes::Node
    include ApplicationHelper

    @node_type = "donationGoalNode"
    @tag_name = "div"

    def tag
      [{ tag: self.class.tag_name, attrs: (@node.attrs || {}).merge({ class: "donationGoal flex flex-col" }) }]
    end

    def matching
      @node.type == self.class.node_type
    end

    def text
      goal = ProsemirrorService::Renderer.event.donation_goal
      "<p>#{render_money goal.progress_amount_cents} / #{render_money goal.amount_cents}</p><div class=\"bg-black rounded-full w-full\"></div>"
    end

  end
end
