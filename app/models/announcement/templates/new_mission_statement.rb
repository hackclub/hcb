# frozen_string_literal: true

class Announcement
  module Templates
    class NewMissionStatement
      def initialize(event:, author:)
        @event = event
        @author = author
      end

      def title
        "Update from #{@event.name}"
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
                  text: "We're happy to announce our organization's updated mission:",
                },
              ],
            },
            { type: "blockquote", content: [{ type: "text", text: @event.description }] },
            {
              type: "paragraph",
              content: [
                { type: "text", text: "Thank you so much for your support!" },
              ],
            },
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
