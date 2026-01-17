# frozen_string_literal: true

json.array! @tags, partial: "api/v4/tags/tag", as: :tag
