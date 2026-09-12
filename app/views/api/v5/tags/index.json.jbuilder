# frozen_string_literal: true

json.data @tags, partial: "api/v5/tags/tag", as: :tag
pagination_metadata(json)
