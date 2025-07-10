# frozen_string_literal: true

module ProsemirrorService
  class DonationSummaryNode < ProsemirrorToHtml::Nodes::Node
    include ApplicationHelper

    @node_type = "donationSummary"
    @tag_name = "div"

    def tag
      [{ tag: self.class.tag_name, attrs: (@node.attrs || {}).merge({ class: "donationSummary relative card shadow-none border flex flex-col py-2 my-2" }) }]
    end

    def matching
      @node.type == self.class.node_type
    end

    def text
      event = ProsemirrorService::Renderer.event
      donations = event.donations.where(aasm_state: [:in_transit, :deposited], created_at: 1.month.ago..).order(:created_at)

      <<-HTML.chomp
        <p class="font-bold">Donation summary for #{1.month.ago.strftime("%B %e, %Y")} - #{Time.now.strftime("%B %e, %Y")}</p>
        <ul>
          #{donations.map do |donation|
            recurring_times = donation.recurring? ? (donation.recurring_donation.donations.find_index(donation) + 1) : 0
            "<li>#{CGI.escape_html(donation.name)} donated #{render_money donation.amount} #{"- this is their #{recurring_times}#{recurring_times.ordinal} monthly donation" if donation.recurring?}</li>"
          end.join}
        </ul>
      HTML
    end

  end
end
