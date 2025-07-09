# frozen_string_literal: true

module ProsemirrorService
  class DonationGoalNode < ProsemirrorToHtml::Nodes::Node
    include ApplicationHelper

    @node_type = "donationGoal"
    @tag_name = "div"

    def tag
      [{ tag: self.class.tag_name, attrs: (@node.attrs || {}).merge({ class: "donationGoal flex flex-col py-2" }) }]
    end

    def matching
      @node.type == self.class.node_type
    end

    def text
      goal = ProsemirrorService::Renderer.event.donation_goal
      percentage = goal.progress_amount_cents.to_f / goal.amount_cents
      <<-HTML.chomp
        <div class="donationGoal flex flex-col">
          <p class="text-center italic"><span class="font-bold">#{render_money goal.progress_amount_cents}</span> raised of <span class="font-bold">#{render_money goal.amount_cents}</span> goal </p>
          <div class="bg-gray-200 dark:bg-neutral-700 rounded-full w-full h-4">
            <div class="h-full bg-primary rounded flex items-center justify-center" style="width: #{percentage * 100}%">
              <p class="text-sm text-black">#{number_with_precision(percentage * 100, precision: 1)}%</p>
            </div>
          </div>
        </div>
      HTML
    end

  end
end
