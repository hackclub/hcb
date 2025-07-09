# frozen_string_literal: true

module ProsemirrorService
  class DonationGoalNode < ProsemirrorToHtml::Nodes::Node
    include ApplicationHelper

    @node_type = "donationGoal"
    @tag_name = "div"

    def tag
      [{ tag: self.class.tag_name, attrs: (@node.attrs || {}).merge({ class: "donationGoal flex flex-col" }) }]
    end

    def matching
      @node.type == self.class.node_type
    end

    def text
      goal = ProsemirrorService::Renderer.event.donation_goal
      percentage = goal.progress_amount_cents.to_f / goal.amount_cents
      <<-HTML.chomp
        <div class="">
        </div>
      HTML
    end

  end
end
