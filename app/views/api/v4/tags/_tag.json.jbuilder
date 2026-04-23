# frozen_string_literal: true

object_shape(json, tag) do
  json.label tag.label
  json.color tag.color
  json.emoji tag.emoji
end
