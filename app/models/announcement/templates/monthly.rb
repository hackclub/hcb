# frozen_string_literal: true

class Announcement
  module Templates
    class Monthly
      include ApplicationHelper

      def initialize(event:, author:)
        @event = event
        @author = author
      end

      def title
        "#{Date.current.strftime("%B %Y")} Update"
      end

      def json_content(block)
        {
          type: "doc",
          content: [
            { type: "paragraph", content: [{ type: "text", text: "Hey all!" }] },
            {
              type: "paragraph",
              content: [
                {
                  type: "text",
                  text: "Thank you for your support and generosity! With this funding, we'll be able to better work towards our mission.",
                },
              ],
            },
            {
              type: "paragraph",
              content: [
                {
                  type: "text",
                  text: "We'd like to thank all of the donors from the past month that contributed towards our organization:",
                },
              ],
            },
            { type: "donationSummary", attrs: { id: block.id } },
            {
              type: "paragraph",
              content: [
                { type: "text", text: "Best," },
                { type: "hardBreak" },
                { type: "text", text: "The #{@event.name} team" },
              ],
            },
          ],
        }
      end

      def create
        announcement = Announcement.create!(event: @event, title:, content: {}, aasm_state: :template_draft, author: @author, template_type: self.class.name)
        block = Announcement::Block::DonationSummary.create!(announcement:, parameters: { start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month })
        announcement.update!(content: json_content(block))

        announcement
      end

    end

  end

end
