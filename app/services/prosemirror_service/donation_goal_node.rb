# frozen_string_literal: true

module ProsemirrorService
  class DonationGoalNode < ProsemirrorToHtml::Nodes::Node
    include ApplicationHelper

    @node_type = "donationGoal"
    @tag_name = "div"

    def tag
      [{ tag: self.class.tag_name, attrs: (@node.attrs.to_h || {}).merge({ class: "donationGoal relative card shadow-none border flex flex-col py-2 my-2" }) }]
    end

    def matching
      @node.type == self.class.node_type
    end

    def text
      event = ProsemirrorService::Renderer.context.fetch(:event)
      is_email = ProsemirrorService::Renderer.context.fetch(:is_email)

      goal = event.donation_goal
      percentage = (goal.progress_amount_cents.to_f / goal.amount_cents) if goal.present?

      AnnouncementsController.renderer.render partial: "announcements/nodes/donation_goal", locals: { goal:, percentage:, is_email: }
    end

  end
end
