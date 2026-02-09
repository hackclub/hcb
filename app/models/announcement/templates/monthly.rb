# frozen_string_literal: true

class Announcement
  module Templates
    class Monthly
      def initialize(event:, author:)
        @event = event
        @author = author
      end

      def title
        "#{Date.current.strftime("%B %Y")} Update"
      end

      def json_content(donation_summary_block:, donation_goal_block:, top_categories_block:)
        donation_goal_component = []
        unless donation_goal_block.empty?
          donation_goal_component = [
            {
              type: "paragraph",
              content: [
                {
                  type: "text",
                  text: "This past month, we've made a lot of progress towards our donation goal:"
                }
              ]
            },
            { type: "Announcement::Block::DonationGoal", attrs: { id: donation_goal_block.id } }
          ]
        end

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
                  text: "Firstly, we'd like to thank all of the donors from the past month that contributed towards our organization:",
                },
              ],
            },
            { type: "Announcement::Block::DonationSummary", attrs: { id: donation_summary_block.id } },
            *donation_goal_component,
            {
              type: "paragraph",
              content: [
                {
                  type: "text",
                  text: "Here's a quick overview of what we've used our funds for this past month:",
                },
              ],
            },
            { type: "Announcement::Block::TopCategories", attrs: { id: top_categories_block.id } },
            if @event.is_public
              {
                type: "paragraph",
                content: [
                  {
                    type: "text",
                    text: "You can see all of our transactions at ",
                  },
                  {
                    type: "text",
                    marks: [
                      {
                        type: "link",
                        attrs: {
                          href: "https://hcb.hackclub.com/#{@event.slug}",
                          target: "_blank",
                          rel: "noopener noreferrer nofollow",
                        },
                      },
                    ],
                    text: "https://hcb.hackclub.com/#{@event.slug}",
                  },
                  { type: "text", text: "." }
                ],
              }
            else
              nil
            end,
            {
              type: "paragraph",
              content: [
                { type: "text", text: "Best," },
                { type: "hardBreak" },
                { type: "text", text: "The #{@event.name} team" },
              ],
            },
          ].compact,
        }
      end

      def create
        announcement = Announcement.create!(event: @event, title:, content: {}, aasm_state: :template_draft, author: @author, template_type: self.class.name)

        donation_summary_block = Announcement::Block::DonationSummary.create!(announcement:, parameters: { start_date: Date.today.beginning_of_month, end_date: Date.today.end_of_month })
        donation_goal_block = Announcement::Block::DonationGoal.create!(announcement:)
        top_categories_block = Announcement::Block::TopCategories.create!(announcement:, parameters: { start_date: Date.today.beginning_of_month, end_date: Date.today.end_of_month })

        announcement.update!(content: json_content(donation_summary_block:, donation_goal_block:, top_categories_block:))
      end

    end

  end

end
