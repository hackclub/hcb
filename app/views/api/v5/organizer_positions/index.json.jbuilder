# frozen_string_literal: true

json.data @organizer_positions, partial: "api/v5/organizer_positions/organizer_position", as: :organizer_position
pagination_metadata(json)
