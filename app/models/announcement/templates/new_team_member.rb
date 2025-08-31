# frozen_string_literal: true

class Announcement
  module Templates
    class NewTeamMember
      def initialize(invite:, author:)
        @invite = invite
        @author = author
      end

      def title
        "Introducing #{@invite.user.name}"
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
                  text: "We're excited to introduce #{@invite.user.name}, who is joining our team!",
                },
              ],
            },
            {
              type: "paragraph",
              content: [
                {
                  type: "text",
                  text: "They'll be working on...",
                },
              ],
            },
            {
              type: "paragraph",
              content: [
                { type: "text", text: "Best," },
                { type: "hardBreak" },
                { type: "text", text: "The #{@invite.event.name} team" },
              ],
            },
          ],
        }
      end

      def create
        Announcement.create!(event: @invite.event, title:, content: json_content, aasm_state: :template_draft, author: @author, template_type: self.class.name)
      end

    end

  end

end
