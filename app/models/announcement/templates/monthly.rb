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
        "Monthly announcement for #{Date.current.month}"
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
            { type: "donationSummary", attrs: { startDate: Time.now.last_month.beginning_of_month.. } },
            {
              type: "paragraph",
              content: [
                { type: "text", text: "Best," },
                { type: "hardBreak" },
                { type: "text", text: "The #{@event.name} team" },
              ],
            },
          ],
        }.to_json
      end

      def create
        Announcement.create!(event: @event, title:, content: json_content, aasm_state: :template_draft, author: @author, template: "Monthly")
      end

    end

  end

end
