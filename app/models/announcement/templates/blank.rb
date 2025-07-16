# frozen_string_literal: true

class Announcement
  module Templates
    class Blank
      def initialize(event:, author:)
        @event = event
        @author = author
      end

      def title
        ""
      end

      def json_content
        {
          type: "doc",
          content: [
            {
              type: "paragraph",
            },
          ],
        }.to_json
      end

      def create
        Announcement.create!(event: @event, title:, content: json_content, aasm_state: :template_draft, author: @author)
      end

    end

  end

end
