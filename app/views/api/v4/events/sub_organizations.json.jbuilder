# frozen_string_literal: true

json.array! @events, partial: "api/v4/events/event", as: :event
