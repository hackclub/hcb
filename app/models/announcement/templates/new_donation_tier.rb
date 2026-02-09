# frozen_string_literal: true

class Announcement
  module Templates
    class NewDonationTier
      def initialize(donation_tier:, author:)
        @donation_tier = donation_tier
        @author = author
      end

      def title
        "New donation tier for #{@donation_tier.event.name}"
      end

      def json_content
        {
          type: "doc",
          content: [
            { type: "paragraph", content: [{ type: "text", text: "Hey all!" }] },
            {
              type: "paragraph",
              content: [
                {
                  type: "text",
                  text: "We're excited to announce a new donation tier for #{@donation_tier.event.name}: ",
                },
              ],
            },
            {
              type: "paragraph",
              content: [
                { type: "text", marks: [{ type: "bold" }], text: @donation_tier.name },
                { type: "text", text: " for " },
                { type: "text", marks: [{ type: "bold" }], text: ApplicationController.helpers.render_money(@donation_tier.amount_cents) },
                { type: "hardBreak" },
                { type: "text", marks: [{ type: "italic" }], text: @donation_tier.description.presence || "Description" },
              ],
            },
            {
              type: "paragraph",
              content: [
                {
                  type: "text",
                  text: "You can donate to this tier by going to ",
                },
                {
                  type: "text",
                  marks: [
                    {
                      type: "link",
                      attrs: {
                        href: "https://hcb.hackclub.com/donations/start/#{@donation_tier.event.slug}",
                        target: "_blank",
                        rel: "noopener noreferrer nofollow",
                      },
                    },
                  ],
                  text: "https://hcb.hackclub.com/donations/start/#{@donation_tier.event.slug}",
                },
                { type: "text", text: "." },
              ],
            },
            {
              type: "paragraph",
              content: [
                { type: "text", text: "Best," },
                { type: "hardBreak" },
                { type: "text", text: "The #{@donation_tier.event.name} team" },
              ],
            }
          ]
        }
      end

      def create
        Announcement.create!(event: @donation_tier.event, title:, content: json_content, aasm_state: :template_draft, author: @author, template_type: self.class.name)
      end

    end

  end

end
