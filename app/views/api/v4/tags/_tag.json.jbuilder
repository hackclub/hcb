# frozen_string_literal: true

# locals: (json:, tag:)

object_shape(json, tag) do
  json.label tag.label
  json.color tag.color
  json.emoji tag.emoji
end
