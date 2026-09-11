# frozen_string_literal: true

json.data @events, partial: "api/v5/events/event", as: :event
pagination_metadata(json)
