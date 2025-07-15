# frozen_string_literal: true

module ProsemirrorService
  class DonationTierNode < ProsemirrorToHtml::Nodes::Node
    include ApplicationHelper

    @node_type = "donationTier"
    @tag_name = "div"

    def tag
      [{ tag: self.class.tag_name, attrs: (@node.attrs.to_h || {}).merge({ class: "donationTier relative card shadow-none border flex flex-col py-2 my-2" }) }]
    end

    def matching
      @node.type == self.class.node_type
    end

    def text
      event = ProsemirrorService::Renderer.context.fetch(:event)

      tier = Donation::Tier.find(@node.attrs.id)

      unless tier.event == event
        tier = nil
      end

      AnnouncementsController.renderer.render partial: "announcements/nodes/donation_tier", locals: { tier: }
    end

  end
end
