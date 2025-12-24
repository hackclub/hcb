# frozen_string_literal: true

expand @event do
  json.array! @tags, partial: "api/v4/tags/tag", as: :tag
end
