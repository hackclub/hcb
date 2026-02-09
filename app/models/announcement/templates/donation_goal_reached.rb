# frozen_string_literal: true

class Announcement
  module Templates
    class DonationGoalReached
      def initialize(event:, author:)
        @event = event
        @author = author
      end

      def title
        "We've reached our donation goal!"
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
                  text: "Thank you for your support and generosity! After #{ApplicationController.helpers.distance_of_time_in_words @event.donation_goal.tracking_since, DateTime.now}, we've reached our donation goal of #{ApplicationController.helpers.render_money @event.donation_goal.amount_cents}. With this funding, we'll be able to better work towards our mission.",
                },
              ],
            },
            {
              type: "paragraph",
              content: [
                {
                  type: "text",
                  text: "We'd like to thank all of the donors that contributed towards our goal:",
                },
              ],
            },
            { type: "donationSummary", attrs: { startDate: @event.donation_goal.tracking_since } },
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
        Announcement.create!(event: @event, title:, content: json_content, aasm_state: :template_draft, author: @author, template_type: self.class.name)
      end

    end

  end

end
