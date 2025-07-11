# frozen_string_literal: true

module ProsemirrorService
  class DonationSummaryNode < ProsemirrorToHtml::Nodes::Node
    include ApplicationHelper

    @node_type = "donationSummary"
    @tag_name = "div"

    def tag
      [{ tag: self.class.tag_name, attrs: (@node.attrs.to_h || {}).merge({ class: "donationSummary relative card shadow-none border flex flex-col py-2 my-2" }) }]
    end

    def matching
      @node.type == self.class.node_type
    end

    def text
      event = ProsemirrorService::Renderer.context.fetch(:event)

      donations = event.donations.where(aasm_state: [:in_transit, :deposited], created_at: 1.month.ago..).order(:created_at)
      total = donations.sum(:amount)

      AnnouncementsController.renderer.render partial: "announcements/nodes/donation_summary", locals: { donations:, total: }
    end

  end
end
