# frozen_string_literal: true

pagination_metadata(json)

json.data @organizer_positions, partial: "api/v4/organizer_positions/organizer_position", as: :organizer_position
