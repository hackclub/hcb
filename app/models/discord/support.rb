# frozen_string_literal: true

module Discord
  module Support
    def button_to(label, url_or_custom_id, **options)
      if url_or_custom_id.start_with?("http")
        {
          type: 2,
          url: url_or_custom_id,
          label:,
          style: 5,
          emoji: { id: "1424492375295791185" }
        }
      else
        {
          type: 2,
          custom_id: url_or_custom_id,
          label: label,
          style: 1,
        }.merge(options || {})
      end
    end

    def link_to(label, url)
      "[#{label}](#{url})"
    end

    def url_helpers
      Rails.application.routes.url_helpers
    end

    def format_components(components)
      return [] unless components.present?

      if !components.is_a?(Array)
        components = [components]
      end

      if components.any? && components.first[:type] != 1
        components = [
          {
            type: 1,
            components: components
          }
        ]
      end

      components
    end

    def color
      if Rails.env.development?
        0x33d6a6
      else
        0xec3750
      end
    end

    def emoji_icon(name)
      {
        id: {
          payment_docs: "1428571025804890245"
        }[name]
      }
    end
  end
end
