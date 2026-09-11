# frozen_string_literal: true

# locals: (json:, tag:)

object_shape(json, tag, created_at: false) do |f|
  f.label tag.label
  f.color tag.color
  f.emoji tag.emoji
end
